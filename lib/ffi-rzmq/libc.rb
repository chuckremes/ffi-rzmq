
module LibC
  extend FFI::Library
  # figures out the correct libc for each platform including Windows
  library = ffi_lib(FFI::Library::LIBC).first

  # Size_t not working properly on Windows
  find_type(:size_t) rescue typedef(:ulong, :size_t)

  # memory allocators
  attach_function :malloc, [:size_t], :pointer
  attach_function :free, [:pointer], :void
  
  # get a pointer to the free function; used for ZMQ::Message deallocation
  Free = library.find_symbol('free')

  # memory movers
  attach_function :memcpy, [:pointer, :pointer, :size_t], :pointer
end # module LibC
