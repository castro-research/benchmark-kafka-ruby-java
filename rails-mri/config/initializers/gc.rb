# if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'truffleruby'
#   unless GC.respond_to?(:compact)
#     module GC
#       def self.compact; end
#     end
#   end

#   module Karafka
#     module Connection
#       class Client
#         alias_method :_orig_poll, :poll

#         # Garante que o FFI receba Integer (ms)
#         def poll(timeout)
#           _orig_poll(Integer(timeout))
#         end
#       end
#     end
#   end
# end
