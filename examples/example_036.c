  typedef struct { void* vt; void* obj; } IWriter;
  int writer_write(IWriter w, char* buf, int len){
      int (*f)(void*,char*,int) = *(int(**)(void*,char*,int))w.vt;
      return f(w.obj, buf, len);
  }
  