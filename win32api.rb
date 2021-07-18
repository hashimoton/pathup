# coding: utf-8
# Win32API via Fiddler taken from:
# https://mirichi.hatenadiary.org/entry/20130629/p1

require 'fiddle'
require 'fiddle/function'

class Win32API
  DLL = {}
  TYPEMAP = {"0" => Fiddle::TYPE_VOID, "S" => Fiddle::TYPE_VOIDP, "I" => Fiddle::TYPE_LONG}
  POINTER_TYPE = Fiddle::SIZEOF_VOIDP == Fiddle::SIZEOF_LONG_LONG ? 'q*' : 'l!*'

  def initialize(dllname, func, import, export = "0", calltype = :stdcall)
    @proto = [import].join.tr("VPpNnLlIi", "0SSI").sub(/^(.)0*$/, '\1')
    handle = DLL[dllname] ||= Fiddle.dlopen(dllname)
    temp = import.each_char.map{|s|s.tr("VPpNnLlIi", "0SSI")}.map{|v|TYPEMAP[v]}
    @func = Fiddle::Function.new(handle[func], temp, TYPEMAP[export.tr("VPpNnLlIi", "0SSI")], calltype == :stdcall ? Fiddle::Function::STDCALL : Fiddle::Function::DEFAULT)
  rescue Fiddle::DLError => e
    raise LoadError, e.message, e.backtrace
  end

  def call(*args)
    import = @proto.split("")
    args.each_with_index do |x, i|
      args[i], = [x == 0 ? nil : x].pack("p").unpack(POINTER_TYPE) if import[i] == "S"
      args[i], = [x].pack("I").unpack("i") if import[i] == "I"
    end
    ret, = @func.call(*args)
    return ret || 0
  end

  alias Call call
end

# EOF
