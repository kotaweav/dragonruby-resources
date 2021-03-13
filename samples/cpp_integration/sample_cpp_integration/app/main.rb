trace! $gtk.ffi_misc.gtk_dlopen('ext')
include FFI::CExt

def tick args
  a = 30
  b = 50
  args.outputs.labels << {
    x: 300, y: 300, text: "gcd of #{a} and #{b}: #{greatest_common_divisor(a, b)}"
  }
end
