void retro_poll_mame_input(void);

static int rtwi=320,rthe=240,topw=1024; // DEFAULT TEXW/TEXH/PITCH
int SHIFTON=-1;
char RPATH[512];
int RETRO_FATAL_ERROR=0;

extern int mmain(int argc, const char *argv);
extern bool draw_this_frame;

#if !defined(HAVE_OPENGL) && !defined(HAVE_OPENGLES) && !defined(HAVE_RGB32)
#define M16B
#endif

#ifdef M16B
	uint16_t videoBuffer[1024*1024];
	#define PITCH 1
#else
	unsigned int videoBuffer[1024*1024];
	#define PITCH 2*1
#endif 

retro_video_refresh_t video_cb = NULL;
retro_environment_t environ_cb = NULL;

const char *retro_save_directory;
const char *retro_system_directory;
const char *retro_content_directory;

retro_log_printf_t log_cb;

static retro_input_state_t input_state_cb = NULL;
static retro_audio_sample_batch_t audio_batch_cb = NULL;

#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES)
#include "retroogl.c"
#endif

void retro_set_audio_sample_batch(retro_audio_sample_batch_t cb) { audio_batch_cb = cb; }
static retro_input_poll_t input_poll_cb;

void retro_set_input_state(retro_input_state_t cb) { input_state_cb = cb; }
void retro_set_input_poll(retro_input_poll_t cb) { input_poll_cb = cb; }

void retro_set_video_refresh(retro_video_refresh_t cb) { video_cb = cb; }
void retro_set_audio_sample(retro_audio_sample_t cb) { }

void retro_set_environment(retro_environment_t cb)
{
   static const struct retro_variable vars[] = {
      { "mame2009_mouse_enable", "Mouse supported; disabled|enabled" },
      { "mame2009_cheat_enable", "Mouse supported; disabled|enabled" },
      { "mame2009_videoapproach1_enable", "Video approach 1 Enabled; disabled|enabled" },
      { NULL, NULL },
   };

   environ_cb = cb;

   cb(RETRO_ENVIRONMENT_SET_VARIABLES, (void*)vars);
}

static void check_variables(void)
{
   struct retro_variable var = {0};
   var.key = "mame2009_mouse_enable";

   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
   {
      fprintf(stderr, "value: %s\n", var.value);
      if (!strcmp(var.value, "disabled"))
         mouse_enable = false;
      if (!strcmp(var.value, "enabled"))
         mouse_enable = true;
   }

   var.key = "mame2009_cheat_enable";
   var.value = NULL;

   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
   {
      fprintf(stderr, "value: %s\n", var.value);
      if (!strcmp(var.value, "disabled"))
         cheats_enable = false;
      if (!strcmp(var.value, "enabled"))
         cheats_enable = true;
   }

   var.key = "mame2009_videoapproach1_enable";
   var.value = NULL;

   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
   {
      fprintf(stderr, "value: %s\n", var.value);
      if (!strcmp(var.value, "disabled"))
         videoapproach1_enable = false;
      if (!strcmp(var.value, "enabled"))
         videoapproach1_enable = true;
   }

}

unsigned retro_api_version(void)
{
   return RETRO_API_VERSION;
}

void retro_get_system_info(struct retro_system_info *info)
{   	
   memset(info, 0, sizeof(*info));
   info->library_name = "MAME 2009";
#ifndef GIT_VERSION
#define GIT_VERSION ""
#endif
   info->library_version = "0.135" GIT_VERSION;
   info->valid_extensions = "zip|chd|7z";
   info->need_fullpath = true;   
   info->block_extract = true;
}

void retro_get_system_av_info(struct retro_system_av_info *info)
{
   check_variables();

   info->geometry.base_width  = rtwi;
   info->geometry.base_height = rthe;

   if (log_cb)
      log_cb(RETRO_LOG_INFO, "AV_INFO: width=%d height=%d\n",info->geometry.base_width,info->geometry.base_height);

   info->geometry.max_width    = 1024;
   info->geometry.max_height   = 768;

   if (log_cb)
      log_cb(RETRO_LOG_INFO, "AV_INFO: max_width=%d max_height=%d\n",info->geometry.max_width,info->geometry.max_height);

   info->geometry.aspect_ratio = retro_aspect;

   if (log_cb)
      log_cb(RETRO_LOG_INFO, "AV_INFO: aspect_ratio = %f\n",info->geometry.aspect_ratio);

   info->timing.fps            = retro_fps;
   info->timing.sample_rate    = 48000.0;

   if (log_cb)
      log_cb(RETRO_LOG_INFO, "AV_INFO: fps = %f sample_rate = %f\n",info->timing.fps,info->timing.sample_rate);

}

void retro_init (void)
{
   struct retro_log_callback log;
   const char *system_dir  = NULL;
   const char *content_dir = NULL;
   const char *save_dir    = NULL;

   if (environ_cb(RETRO_ENVIRONMENT_GET_LOG_INTERFACE, &log))
      log_cb = log.log;
   else
      log_cb = NULL;

   if (environ_cb(RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY, &system_dir) && system_dir)
   {
      /* if defined, use the system directory */
      retro_system_directory = system_dir;
   }

   if (log_cb)
      log_cb(RETRO_LOG_INFO, "SYSTEM_DIRECTORY: %s", retro_system_directory);

   if (environ_cb(RETRO_ENVIRONMENT_GET_CONTENT_DIRECTORY, &content_dir) && content_dir)
   {
      // if defined, use the system directory
      retro_content_directory=content_dir;
   }

   if (log_cb)
      log_cb(RETRO_LOG_INFO, "CONTENT_DIRECTORY: %s", retro_content_directory);


   if (environ_cb(RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY, &save_dir) && save_dir)
   {
      /* If save directory is defined use it, 
       * otherwise use system directory. */
      retro_save_directory = *save_dir ? save_dir : retro_system_directory;

   }
   else
   {
      /* make retro_save_directory the same,
       * in case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY 
       * is not implemented by the frontend. */
      retro_save_directory=retro_system_directory;
   }
   if (log_cb)
      log_cb(RETRO_LOG_INFO, "SAVE_DIRECTORY: %s", retro_save_directory);
}

extern void retro_finish();
extern void retro_main_loop();

int RLOOP=1;

void retro_deinit(void)
{
   if(retro_load_ok)retro_finish();
   LOGI("Retro DeInit\n");
}

void retro_reset (void)
{
   mame_reset = 1;
}


void retro_run (void)
{ 
   int result;
   static int runfirst=1;
   bool updated = false;

   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE, &updated) && updated)
      check_variables();

   if(runfirst==1)
   {
 	runfirst++;
   	result=mmain(1,RPATH);
   	if(result!=1){
        	printf("Error: mame return an error\n");
		exit(0);
   	} 
        retro_load_ok  = true;

	return;
   }

   if (NEWGAME_FROM_OSD == 1)
   {
      struct retro_system_av_info ninfo;

      retro_get_system_av_info(&ninfo);

      environ_cb(RETRO_ENVIRONMENT_SET_SYSTEM_AV_INFO, &ninfo);

      if (log_cb)
         log_cb(RETRO_LOG_INFO, "ChangeAV: w:%d h:%d ra:%f.\n",
               ninfo.geometry.base_width, ninfo.geometry.base_height, ninfo.geometry.aspect_ratio);

      NEWGAME_FROM_OSD=0;
   }

   if(RETRO_FATAL_ERROR==1){
	LOGI("MAME FATAL ERROR! exit now.\n");
	exit(0);
   }
	retro_main_loop();
	retro_poll_mame_input();
	RLOOP=1;

#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES)
	do_gl2d();
#else
	if (draw_this_frame)
      		video_cb(videoBuffer,rtwi, rthe, topw << PITCH);
   	else
      		video_cb(NULL,rtwi, rthe, topw << PITCH); 
#endif
}

void prep_retro_rotation(int rot)
{
   LOGI("Rotation:%d\n",rot);
   environ_cb(RETRO_ENVIRONMENT_SET_ROTATION, &rot);
}

/*
static void keyboard_cb(bool down, unsigned keycode, uint32_t character, uint16_t mod)
{
#ifdef KEYDBG
   printf( "Down: %s, Code: %d, Char: %u, Mod: %u. \n",
         down ? "yes" : "no", keycode, character, mod);
#endif
   if (keycode>=320);
   else
   {
      if(down && keycode==RETROK_LSHIFT)
      {
         SHIFTON=-SHIFTON;					
         if(SHIFTON == 1)
            retrokbd_state[keycode]=1;
         else
            retrokbd_state[keycode]=0;	
      }
      else if(keycode!=RETROK_LSHIFT)
      {
         if (down)
            retrokbd_state[keycode]=1;	
         else if (!down)
            retrokbd_state[keycode]=0;
      }
   }
}
*/
bool retro_load_game(const struct retro_game_info *info) 
{
   char basename[128];
   int result=0;
#if 0
   struct retro_keyboard_callback cb = { keyboard_cb };
   environ_cb(RETRO_ENVIRONMENT_SET_KEYBOARD_CALLBACK, &cb);
#endif

#ifndef M16B
   enum retro_pixel_format fmt =RETRO_PIXEL_FORMAT_XRGB8888;
#else
   enum retro_pixel_format fmt = RETRO_PIXEL_FORMAT_RGB565;
#endif

   if (!environ_cb(RETRO_ENVIRONMENT_SET_PIXEL_FORMAT, &fmt))
   {
      fprintf(stderr, "RGB pixel format is not supported.\n");
      exit(0);
   }
   check_variables();

#ifdef M16B
   memset(videoBuffer,0,1024*1024*2);
#else
   memset(videoBuffer,0,1024*1024*2*2);
#endif

#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES)
#ifdef HAVE_OPENGLES
   hw_render.context_type = RETRO_HW_CONTEXT_OPENGLES2;
#else
   hw_render.context_type = RETRO_HW_CONTEXT_OPENGL;
#endif
   hw_render.context_reset = context_reset;
   hw_render.context_destroy = context_destroy;

   if (!environ_cb(RETRO_ENVIRONMENT_SET_HW_RENDER, &hw_render))
      return false;
#endif

   basename[0] = '\0';
   extract_basename(basename, info->path, sizeof(basename));
   extract_directory(g_rom_dir, info->path, sizeof(g_rom_dir));
   strcpy(RPATH,info->path);

   RETRO_FATAL_ERROR=0;

printf("Exit retro_load_game\n");
   return 1;
}

void retro_unload_game(void)
{
	if(pauseg==0)
		pauseg=-1;				

	LOGI("Retro unload_game\n");	
}

// Stubs
size_t retro_serialize_size(void){ return 0; }
bool retro_serialize(void *data, size_t size){ return false; }
bool retro_unserialize(const void * data, size_t size){ return false; }

unsigned retro_get_region (void) {return RETRO_REGION_NTSC;}
void *retro_get_memory_data(unsigned type) {return 0;}
size_t retro_get_memory_size(unsigned type) {return 0;}
bool retro_load_game_special(unsigned game_type, const struct retro_game_info *info, size_t num_info){return false;}
void retro_cheat_reset(void){}
void retro_cheat_set(unsigned unused, bool unused1, const char* unused2){}
void retro_set_controller_port_device(unsigned in_port, unsigned device){}
