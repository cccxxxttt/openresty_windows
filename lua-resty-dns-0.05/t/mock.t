# vim:set ft= ts=4 sw=4 et:

use lib 't';
use TestDNS;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * (3 * blocks() + 2);

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
    lua_package_cpath "/usr/local/openresty-debug/lualib/?.so;/usr/local/openresty/lualib/?.so;;";
};

$ENV{TEST_NGINX_RESOLVER} = '8.8.8.8';

#no_long_string();

run_tests();

__DATA__

=== TEST 1: single answer reply, good A answer
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local resolver = require "resty.dns.resolver"

            local r, err = resolver:new{
                nameservers = { {"127.0.0.1", 1953} }
            }
            if not r then
                ngx.say("failed to instantiate resolver: ", err)
                return
            end

            r._id = 125

            local ans, err = r:query("www.google.com", { qtype = r.TYPE_A })
            if not ans then
                ngx.say("failed to query: ", err)
                return
            end

            local cjson = require "cjson"
            ngx.say("records: ", cjson.encode(ans))
        ';
    }
--- udp_listen: 1953
--- udp_reply dns
{
    id => 125,
    opcode => 0,
    qname => 'www.google.com',
    answer => [{ name => "www.google.com", ipv4 => "127.0.0.1", ttl => 123456 }],
}
--- request
GET /t
--- udp_query eval
"\x{00}}\x{01}\x{00}\x{00}\x{01}\x{00}\x{00}\x{00}\x{00}\x{00}\x{00}\x{03}www\x{06}google\x{03}com\x{00}\x{00}\x{01}\x{00}\x{01}"
--- response_body
records: [{"address":"127.0.0.1","type":1,"class":1,"name":"www.google.com","ttl":123456}]
--- no_error_log
[error]



=== TEST 2: empty answer reply
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local resolver = require "resty.dns.resolver"

            local r, err = resolver:new{
                nameservers = { {"127.0.0.1", 1953} }
            }
            if not r then
                ngx.say("failed to instantiate resolver: ", err)
                return
            end

            r._id = 125

            local ans, err = r:query("www.google.com", { qtype = r.TYPE_A })
            if not ans then
                ngx.say("failed to query: ", err)
                return
            end

            local cjson = require "cjson"
            ngx.say("records: ", cjson.encode(ans))
        ';
    }
--- udp_listen: 1953
--- udp_reply dns
{
    id => 125,
    qname => 'www.google.com',
    opcode => 0,
}
--- request
GET /t
--- response_body
records: {}
--- no_error_log
[error]



=== TEST 3: one byte reply
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local resolver = require "resty.dns.resolver"

            local r, err = resolver:new{
                nameservers = { {"127.0.0.1", 1953} }
            }
            if not r then
                ngx.say("failed to instantiate resolver: ", err)
                return
            end

            local ans, err = r:query("www.google.com", { qtype = r.TYPE_A })
            if not ans then
                ngx.say("failed to query: ", err)
                return
            end

            local cjson = require "cjson"
            ngx.say("records: ", cjson.encode(ans))
        ';
    }
--- udp_listen: 1953
--- udp_reply: a
--- request
GET /t
--- response_body
failed to query: truncated
--- no_error_log
[error]



=== TEST 4: empty reply
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local resolver = require "resty.dns.resolver"

            local r, err = resolver:new{
                nameservers = { {"127.0.0.1", 1953} }
            }
            if not r then
                ngx.say("failed to instantiate resolver: ", err)
                return
            end

            r._id = 125

            local ans, err = r:query("www.google.com", { qtype = r.TYPE_A })
            if not ans then
                ngx.say("failed to query: ", err)
                return
            end

            local cjson = require "cjson"
            ngx.say("records: ", cjson.encode(ans))
        ';
    }
--- udp_listen: 1953
--- udp_reply:
--- request
GET /t
--- response_body
failed to query: truncated
--- no_error_log
[error]



=== TEST 5: two answers reply that contains AAAA records
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local resolver = require "resty.dns.resolver"

            local r, err = resolver:new{
                nameservers = { {"127.0.0.1", 1953} }
            }
            if not r then
                ngx.say("failed to instantiate resolver: ", err)
                return
            end

            r._id = 125

            local ans, err = r:query("www.google.com", { qtype = r.TYPE_A })
            if not ans then
                ngx.say("failed to query: ", err)
                return
            end

            local cjson = require "cjson"
            ngx.say("records: ", cjson.encode(ans))
        ';
    }
--- udp_listen: 1953
--- udp_reply dns
{
    id => 125,
    opcode => 0,
    qname => 'www.google.com',
    answer => [
        { name => "www.google.com", ipv4 => "127.0.0.1", ttl => 123456 },
        { name => "l.www.google.com", ipv6 => "::1", ttl => 0 },
    ],
}
--- request
GET /t
--- response_body
records: [{"address":"127.0.0.1","type":1,"class":1,"name":"www.google.com","ttl":123456},{"address":"0:0:0:0:0:0:0:1","type":28,"class":1,"name":"l.www.google.com","ttl":0}]
--- no_error_log
[error]



=== TEST 6: good CNAME answer
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local resolver = require "resty.dns.resolver"

            local r, err = resolver:new{
                nameservers = { {"127.0.0.1", 1953} }
            }
            if not r then
                ngx.say("failed to instantiate resolver: ", err)
                return
            end

            r._id = 125

            local ans, err = r:query("www.google.com", { qtype = r.TYPE_A })
            if not ans then
                ngx.say("failed to query: ", err)
                return
            end

            local cjson = require "cjson"
            ngx.say("records: ", cjson.encode(ans))
        ';
    }
--- udp_listen: 1953
--- udp_reply dns
{
    id => 125,
    opcode => 0,
    qname => 'www.google.com',
    answer => [
        { name => "www.google.com", cname => "blah.google.com", ttl => 125 },
    ],
}
--- request
GET /t
--- response_body
records: [{"ttl":125,"type":5,"class":1,"name":"www.google.com","cname":"blah.google.com"}]
--- no_error_log
[error]



=== TEST 7: CNAME answer with bad rd length
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local resolver = require "resty.dns.resolver"

            local r, err = resolver:new{
                nameservers = { {"127.0.0.1", 1953} }
            }
            if not r then
                ngx.say("failed to instantiate resolver: ", err)
                return
            end

            r._id = 125

            local ans, err = r:query("www.google.com", { qtype = r.TYPE_A })
            if not ans then
                ngx.say("failed to query: ", err)
                return
            end

            local cjson = require "cjson"
            ngx.say("records: ", cjson.encode(ans))
        ';
    }
--- udp_listen: 1953
--- udp_reply dns
{
    id => 125,
    opcode => 0,
    qname => 'www.google.com',
    answer => [
        { name => "www.google.com", cname => "blah.google.com", ttl => 125, rdlength => 3 },
    ],
}
--- request
GET /t
--- response_body
failed to query: bad cname record length: 17 ~= 3
--- no_error_log
[error]



=== TEST 8: single answer reply, bad A answer, wrong record length
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local resolver = require "resty.dns.resolver"

            local r, err = resolver:new{
                nameservers = { {"127.0.0.1", 1953} }
            }
            if not r then
                ngx.say("failed to instantiate resolver: ", err)
                return
            end

            r._id = 125

            local ans, err = r:query("www.google.com", { qtype = r.TYPE_A })
            if not ans then
                ngx.say("failed to query: ", err)
                return
            end

            local cjson = require "cjson"
            ngx.say("records: ", cjson.encode(ans))
        ';
    }
--- udp_listen: 1953
--- udp_reply dns
{
    id => 125,
    opcode => 0,
    qname => 'www.google.com',
    answer => [{ name => "www.google.com", ipv4 => "127.0.0.1", ttl => 123456, rdlength => 1 }],
}
--- request
GET /t
--- response_body
failed to query: bad A record value length: 1
--- no_error_log
[error]



=== TEST 9: bad AAAA record, wrong len
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local resolver = require "resty.dns.resolver"

            local r, err = resolver:new{
                nameservers = { {"127.0.0.1", 1953} }
            }
            if not r then
                ngx.say("failed to instantiate resolver: ", err)
                return
            end

            r._id = 125

            local ans, err = r:query("www.google.com", { qtype = r.TYPE_A })
            if not ans then
                ngx.say("failed to query: ", err)
                return
            end

            local cjson = require "cjson"
            ngx.say("records: ", cjson.encode(ans))
        ';
    }
--- udp_listen: 1953
--- udp_reply dns
{
    id => 125,
    opcode => 0,
    qname => 'www.google.com',
    answer => [
        { name => "l.www.google.com", ipv6 => "::1", ttl => 0, rdlength => 21 },
    ],
}
--- request
GET /t
--- response_body
failed to query: bad AAAA record value length: 21
--- no_error_log
[error]



=== TEST 10: timeout
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local resolver = require "resty.dns.resolver"

            local r, err = resolver:new{
                nameservers = { {"127.0.0.1", 1953} },
                retrans = 4,
            }
            if not r then
                ngx.say("failed to instantiate resolver: ", err)
                return
            end

            r:set_timeout(10)   -- in ms

            r._id = 125

            local ans, err = r:query("www.google.com", { qtype = r.TYPE_A })
            if not ans then
                ngx.say("failed to query: ", err)
                return
            end

            local cjson = require "cjson"
            ngx.say("records: ", cjson.encode(ans))
        ';
    }
--- udp_listen: 1953
--- udp_reply_delay: 50ms
--- udp_reply dns
{
    id => 125,
    opcode => 0,
    qname => 'www.google.com',
    answer => [
        { name => "l.www.google.com", ipv6 => "::1", ttl => 0 },
    ],
}
--- request
GET /t
--- response_body
failed to query: failed to receive DNS response: timeout
--- error_log
lua udp socket read timed out
--- timeout: 3



=== TEST 11: not timeout finally (re-transmission works)
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local resolver = require "resty.dns.resolver"

            local r, err = resolver:new{
                nameservers = { {"127.0.0.1", 1953} },
                -- retrans = 4,
            }
            if not r then
                ngx.say("failed to instantiate resolver: ", err)
                return
            end

            r:set_timeout(20)   -- in ms

            r._id = 125

            local ans, err = r:query("www.google.com", { qtype = r.TYPE_A })
            if not ans then
                ngx.say("failed to query: ", err)
                return
            end

            local cjson = require "cjson"
            ngx.say("records: ", cjson.encode(ans))
        ';
    }
--- udp_listen: 1953
--- udp_reply_delay: 50ms
--- udp_reply dns
{
    id => 125,
    opcode => 0,
    qname => 'www.google.com',
    answer => [
        { name => "l.www.google.com", ipv6 => "FF01::101", ttl => 0 },
    ],
}
--- request
GET /t
--- response_body
records: [{"address":"ff01:0:0:0:0:0:0:101","type":28,"class":1,"name":"l.www.google.com","ttl":0}]
--- error_log
lua udp socket read timed out
--- timeout: 3



=== TEST 12: timeout finally (re-transmission works but not enough retrans times)
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local resolver = require "resty.dns.resolver"

            local r, err = resolver:new{
                nameservers = { {"127.0.0.1", 1953} },
                retrans = 3,
            }
            if not r then
                ngx.say("failed to instantiate resolver: ", err)
                return
            end

            r:set_timeout(20)   -- in ms

            r._id = 125

            local ans, err = r:query("www.google.com", { qtype = r.TYPE_A })
            if not ans then
                ngx.say("failed to query: ", err)
                return
            end

            local cjson = require "cjson"
            ngx.say("records: ", cjson.encode(ans))
        ';
    }
--- udp_listen: 1953
--- udp_reply_delay: 50ms
--- udp_reply dns
{
    id => 125,
    opcode => 0,
    qname => 'www.google.com',
    answer => [
        { name => "l.www.google.com", ipv6 => "FF01::101", ttl => 0 },
    ],
}
--- request
GET /t
--- response_body
records: [{"address":"ff01:0:0:0:0:0:0:101","type":28,"class":1,"name":"l.www.google.com","ttl":0}]
--- error_log
lua udp socket read timed out
--- timeout: 3



=== TEST 13: RCODE - format error
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local resolver = require "resty.dns.resolver"

            local r, err = resolver:new{
                nameservers = { {"127.0.0.1", 1953} },
                retrans = 3,
            }
            if not r then
                ngx.say("failed to instantiate resolver: ", err)
                return
            end

            r:set_timeout(20)   -- in ms

            r._id = 125

            local ans, err = r:query("www.google.com", { qtype = r.TYPE_A })
            if not ans then
                ngx.say("failed to query: ", err)
                return
            end

            local cjson = require "cjson"
            ngx.say("records: ", cjson.encode(ans))
        ';
    }
--- udp_listen: 1953
--- udp_reply dns
{
    id => 125,
    rcode => 1,
    opcode => 0,
    qname => 'www.google.com',
}
--- request
GET /t
--- response_body
failed to query: server returned code 1: format error
--- no_error_log
[error]



=== TEST 14: RCODE - server failure
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local resolver = require "resty.dns.resolver"

            local r, err = resolver:new{
                nameservers = { {"127.0.0.1", 1953} },
                retrans = 3,
            }
            if not r then
                ngx.say("failed to instantiate resolver: ", err)
                return
            end

            r:set_timeout(20)   -- in ms

            r._id = 125

            local ans, err = r:query("www.google.com", { qtype = r.TYPE_A })
            if not ans then
                ngx.say("failed to query: ", err)
                return
            end

            local cjson = require "cjson"
            ngx.say("records: ", cjson.encode(ans))
        ';
    }
--- udp_listen: 1953
--- udp_reply dns
{
    id => 125,
    rcode => 2,
    opcode => 0,
    qname => 'www.google.com',
}
--- request
GET /t
--- response_body
failed to query: server returned code 2: server failure
--- no_error_log
[error]



=== TEST 15: RCODE - name error
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local resolver = require "resty.dns.resolver"

            local r, err = resolver:new{
                nameservers = { {"127.0.0.1", 1953} },
                retrans = 3,
            }
            if not r then
                ngx.say("failed to instantiate resolver: ", err)
                return
            end

            r:set_timeout(20)   -- in ms

            r._id = 125

            local ans, err = r:query("www.google.com", { qtype = r.TYPE_A })
            if not ans then
                ngx.say("failed to query: ", err)
                return
            end

            local cjson = require "cjson"
            ngx.say("records: ", cjson.encode(ans))
        ';
    }
--- udp_listen: 1953
--- udp_reply dns
{
    id => 125,
    rcode => 3,
    opcode => 0,
    qname => 'www.google.com',
}
--- request
GET /t
--- response_body
failed to query: server returned code 3: name error
--- no_error_log
[error]



=== TEST 16: RCODE - not implemented
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local resolver = require "resty.dns.resolver"

            local r, err = resolver:new{
                nameservers = { {"127.0.0.1", 1953} },
                retrans = 3,
            }
            if not r then
                ngx.say("failed to instantiate resolver: ", err)
                return
            end

            r:set_timeout(20)   -- in ms

            r._id = 125

            local ans, err = r:query("www.google.com", { qtype = r.TYPE_A })
            if not ans then
                ngx.say("failed to query: ", err)
                return
            end

            local cjson = require "cjson"
            ngx.say("records: ", cjson.encode(ans))
        ';
    }
--- udp_listen: 1953
--- udp_reply dns
{
    id => 125,
    rcode => 4,
    opcode => 0,
    qname => 'www.google.com',
}
--- request
GET /t
--- response_body
failed to query: server returned code 4: not implemented
--- no_error_log
[error]



=== TEST 17: RCODE - refused
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local resolver = require "resty.dns.resolver"

            local r, err = resolver:new{
                nameservers = { {"127.0.0.1", 1953} },
                retrans = 3,
            }
            if not r then
                ngx.say("failed to instantiate resolver: ", err)
                return
            end

            r:set_timeout(20)   -- in ms

            r._id = 125

            local ans, err = r:query("www.google.com", { qtype = r.TYPE_A })
            if not ans then
                ngx.say("failed to query: ", err)
                return
            end

            local cjson = require "cjson"
            ngx.say("records: ", cjson.encode(ans))
        ';
    }
--- udp_listen: 1953
--- udp_reply dns
{
    id => 125,
    rcode => 5,
    opcode => 0,
    qname => 'www.google.com',
}
--- request
GET /t
--- response_body
failed to query: server returned code 5: refused
--- no_error_log
[error]



=== TEST 18: RCODE - unknown
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local resolver = require "resty.dns.resolver"

            local r, err = resolver:new{
                nameservers = { {"127.0.0.1", 1953} },
                retrans = 3,
            }
            if not r then
                ngx.say("failed to instantiate resolver: ", err)
                return
            end

            r:set_timeout(20)   -- in ms

            r._id = 125

            local ans, err = r:query("www.google.com", { qtype = r.TYPE_A })
            if not ans then
                ngx.say("failed to query: ", err)
                return
            end

            local cjson = require "cjson"
            ngx.say("records: ", cjson.encode(ans))
        ';
    }
--- udp_listen: 1953
--- udp_reply dns
{
    id => 125,
    rcode => 6,
    opcode => 0,
    qname => 'www.google.com',
}
--- request
GET /t
--- response_body
failed to query: server returned code 6: unknown
--- no_error_log
[error]



=== TEST 19: TC (TrunCation) = 1
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local resolver = require "resty.dns.resolver"

            local r, err = resolver:new{
                nameservers = { {"127.0.0.1", 1953} },
                retrans = 3,
            }
            if not r then
                ngx.say("failed to instantiate resolver: ", err)
                return
            end

            r:set_timeout(20)   -- in ms

            r._id = 125

            local ans, err = r:query("www.google.com", { qtype = r.TYPE_A })
            if not ans then
                ngx.say("failed to query: ", err)
                return
            end

            local cjson = require "cjson"
            ngx.say("records: ", cjson.encode(ans))
        ';
    }
--- udp_listen: 1953
--- udp_reply dns
{
    id => 125,
    tc => 1,
    qname => 'www.google.com',
}
--- request
GET /t
--- response_body
failed to query: truncated
--- no_error_log
[error]



=== TEST 20: bad QR flag (0)
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local resolver = require "resty.dns.resolver"

            local r, err = resolver:new{
                nameservers = { {"127.0.0.1", 1953} },
                retrans = 3,
            }
            if not r then
                ngx.say("failed to instantiate resolver: ", err)
                return
            end

            r:set_timeout(20)   -- in ms

            r._id = 125

            local ans, err = r:query("www.google.com", { qtype = r.TYPE_A })
            if not ans then
                ngx.say("failed to query: ", err)
                return
            end

            local cjson = require "cjson"
            ngx.say("records: ", cjson.encode(ans))
        ';
    }
--- udp_listen: 1953
--- udp_reply dns
{
    id => 125,
    qr => 0,
    qname => 'www.google.com',
}
--- request
GET /t
--- response_body
failed to query: bad QR flag in the DNS response
--- no_error_log
[error]



=== TEST 21: Recursion Desired off
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local resolver = require "resty.dns.resolver"

            local r, err = resolver:new{
                nameservers = { {"127.0.0.1", 1953} },
                retrans = 3,
                no_recurse = true,
            }
            if not r then
                ngx.say("failed to instantiate resolver: ", err)
                return
            end

            r:set_timeout(20)   -- in ms

            r._id = 125

            local ans, err = r:query("www.google.com", { qtype = r.TYPE_A })
            if not ans then
                ngx.say("failed to query: ", err)
                return
            end

            local cjson = require "cjson"
            ngx.say("records: ", cjson.encode(ans))
        ';
    }
--- udp_listen: 1953
--- udp_query eval
"\x{00}}\x{00}\x{00}\x{00}\x{01}\x{00}\x{00}\x{00}\x{00}\x{00}\x{00}\x{03}www\x{06}google\x{03}com\x{00}\x{00}\x{01}\x{00}\x{01}"
--- udp_reply dns
{
    id => 125,
    qname => 'www.google.com',
}
--- request
GET /t
--- response_body
records: {}
--- no_error_log
[error]

