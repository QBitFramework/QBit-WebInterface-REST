#!/usr/bin/perl

use Test::More;
use Test::Deep;

use qbit;

use Digest::MD5 qw(md5_hex);

use lib::abs qw(../lib ../t_lib ../../QBit-WebInterface/t_lib);

use QBit::WebInterface::Test::Request;
use URI::Escape qw(uri_escape_utf8);

use TestWebInterface;

sub get_request {
    my (%opts) = @_;

    return QBit::WebInterface::Test::Request->new(
        path  => $opts{'path'},
        cmd   => $opts{'cmd'},
        query => $opts{'params'}
        ? join('&',
            map {uri_escape_utf8($_) . '=' . uri_escape_utf8($opts{'params'}->{$_})} keys(%{$opts{'params'} || {}}))
        : '',
        method  => $opts{'method'}  || 'GET',
        headers => $opts{'headers'} || {},
        scheme  => $opts{'scheme'}  || 'http'
    );
}

my $wi = new_ok('TestWebInterface');

my $r = $wi->new_routing();

my $error = FALSE;
try {
    $r->get('user');
}
catch {
    $error = TRUE;

    is(shift->message, gettext('Route must begin with "/"'), 'Corrected error');
}
finally {
    ok($error, 'throw exception');
};

$r->get('/')->to(path => 'user', cmd => 'list')->name('user_defualt');

$error = FALSE;
try {
    $r->get('/');
}
catch {
    $error = TRUE;

    is(shift->message, gettext('Route "%s" already exists', '/'), 'Corrected error');
}
finally {
    ok($error, 'throw exception');
};

$r->get('/user/without_last_slash')->to(path => 'user', cmd => 'without_last_slash')->name('user__without_last_slash');

$r->get('/user/with_last_slash/')->to(path => 'user', cmd => 'with_last_slash')->name('user__with_last_slash');

$r->post('/user/add')->to(path => 'user', cmd => 'add')->name('user__add');

$r->any('/user/info**')->name('user__info')->to('user#info');

$r->any([qw(POST PUT PATCH)] => '/user/edit')->name('user__edit')->to(path => 'user', cmd => 'edit');

$r->get('/user/standart/:name:')->to(path => 'user', cmd => 'standart_name')->name('user__standart_name');

$r->get('/user/relaxed/#name#')->to(path => 'user', cmd => 'relaxed_name')->name('user__relaxed_name');

$r->get('/user/wildcard/*name*')->to(path => 'user', cmd => 'wildcard_name')->name('user__wildcard_name');

$error = FALSE;
try {
    $r->post('/user/:action:/:action:');
}
catch {
    $error = TRUE;

    is(shift->message, gettext('Placeholders names can not intersect'), 'Corrected error');
}
finally {
    ok($error, 'throw exception');
};

$r->post('/user/:action:/:id:')->name('user__action')->to(path => 'user', cmd => 'action');

$r->get('/user/:name:-:surname:')->to(
    controller => sub {
        my ($web_interface, $params) = @_;

        if ($params->{'name'} eq 'vasya') {
            return ('user', 'name_surname_vasya');
        } elsif ($params->{'name'} eq 'petya') {
            return ('user', 'name_surname_petya');
        } else {
            return ('', '');
        }
    }
)->name('user__name_surname');

$r->get('/user/:id:')->name('user__profile')->to(path => 'user', cmd => 'profile')
  ->conditions(id => qr/\A[1-9][0-9]*\z/);

$r->get('/user/:id:/settings')->name('user__settings')->to(path => 'user', cmd => 'settings')->conditions(
    id => sub {
        my ($web_interface, $chek_value, $params) = @_;

        return $chek_value >= 1_000 && $chek_value <= 1_500;
    }
);

$r->get('/user/scheme')->conditions(scheme => qr/https/)->to(path => 'user', cmd => 'scheme')->name('user__sheme');

$r->get('/user/mobile')->conditions(user_agent => qr/IEMobile/)->to(path => 'user', cmd => 'mobile')
  ->name('user__mobile');

$r->put('/user/:login:')->conditions(login => [qw(bender)])->to('user#bender');

cmp_deeply(
    $r->{'__ROUTES__'},
    {
        '/user/without_last_slash' => {
            'name'       => 'user__without_last_slash',
            'format'     => '/user/without_last_slash',
            'params'     => [],
            'route_path' => {
                'cmd'  => 'without_last_slash',
                'path' => 'user'
            },
            'methods' => 1,
            'pattern' => '\A\/user\/without_last_slash\z',
            'levels'  => 2
        },
        '/user/:action:/:id:' => {
            'format'     => '/user/%s/%s',
            'name'       => 'user__action',
            'route_path' => {
                'path' => 'user',
                'cmd'  => 'action'
            },
            'params'  => ['action', 'id'],
            'pattern' => '\A\/user\/([^\/.]+)\/([^\/.]+)\z',
            'methods' => 4,
            'levels'  => 3
        },
        '/user/scheme' => {
            'name'       => 'user__sheme',
            'format'     => '/user/scheme',
            'pattern'    => '\A\/user\/scheme\z',
            'methods'    => 1,
            'levels'     => 2,
            'conditions' => {'scheme' => qr/https/},
            'route_path' => {
                'path' => 'user',
                'cmd'  => 'scheme'
            },
            'params' => []
        },
        '/' => {
            'levels'     => 0,
            'format'     => '/',
            'name'       => 'user_defualt',
            'params'     => [],
            'route_path' => {
                'path' => 'user',
                'cmd'  => 'list'
            },
            'methods' => 1,
            'pattern' => '\A\/\z'
        },
        '/user/:id:/settings' => {
            'route_path' => {
                'cmd'  => 'settings',
                'path' => 'user'
            },
            'params'     => ['id'],
            'methods'    => 1,
            'pattern'    => '\A\/user\/([^\/.]+)\/settings\z',
            'format'     => '/user/%s/settings',
            'name'       => 'user__settings',
            'conditions' => {'id' => ignore()},
            'levels'     => 3
        },
        '/user/mobile' => {
            'conditions' => {'user_agent' => qr/IEMobile/},
            'levels'     => 2,
            'pattern'    => '\A\/user\/mobile\z',
            'methods'    => 1,
            'name'       => 'user__mobile',
            'format'     => '/user/mobile',
            'route_path' => {
                'cmd'  => 'mobile',
                'path' => 'user'
            },
            'params' => []
        },
        '/user/relaxed/#name#' => {
            'route_path' => {
                'path' => 'user',
                'cmd'  => 'relaxed_name'
            },
            'params'  => ['name'],
            'pattern' => '\A\/user\/relaxed\/([^\/]+)\z',
            'methods' => 1,
            'name'    => 'user__relaxed_name',
            'format'  => '/user/relaxed/%s',
            'levels'  => 3
        },
        '/user/add' => {
            'levels'     => 2,
            'format'     => '/user/add',
            'name'       => 'user__add',
            'route_path' => {
                'cmd'  => 'add',
                'path' => 'user'
            },
            'methods' => 4,
            'params'  => [],
            'pattern' => '\A\/user\/add\z'
        },
        '/user/info**' => {
            'levels'     => 2,
            'route_path' => {
                'cmd'  => 'info',
                'path' => 'user'
            },
            'methods' => 127,
            'params'  => [],
            'pattern' => '\A\/user\/info\*\z',
            'name'    => 'user__info',
            'format'  => '/user/info*'
        },
        '/user/:id:' => {
            'name'       => 'user__profile',
            'format'     => '/user/%s',
            'methods'    => 1,
            'pattern'    => '\A\/user\/([^\/.]+)\z',
            'levels'     => 2,
            'conditions' => {'id' => qr/\A[1-9][0-9]*\z/},
            'params'     => ['id'],
            'route_path' => {
                'path' => 'user',
                'cmd'  => 'profile'
            }
        },
        '/user/standart/:name:' => {
            'levels'     => 3,
            'name'       => 'user__standart_name',
            'format'     => '/user/standart/%s',
            'methods'    => 1,
            'route_path' => {
                'cmd'  => 'standart_name',
                'path' => 'user'
            },
            'pattern' => '\A\/user\/standart\/([^\/.]+)\z',
            'params'  => ['name']
        },
        '/user/wildcard/*name*' => {
            'format'     => '/user/wildcard/%s',
            'name'       => 'user__wildcard_name',
            'params'     => ['name'],
            'route_path' => {
                'path' => 'user',
                'cmd'  => 'wildcard_name'
            },
            'pattern' => '\A\/user\/wildcard\/(.+)\z',
            'methods' => 1,
            'levels'  => 3
        },
        '/user/with_last_slash/' => {
            'levels'     => 2,
            'route_path' => {
                'cmd'  => 'with_last_slash',
                'path' => 'user'
            },
            'methods' => 1,
            'params'  => [],
            'pattern' => '\A\/user\/with_last_slash\/\z',
            'format'  => '/user/with_last_slash/',
            'name'    => 'user__with_last_slash'
        },
        '/user/:login:' => {
            'conditions' => {'login' => ['bender']},
            'levels'     => 2,
            'route_path' => {
                'cmd'  => 'bender',
                'path' => 'user'
            },
            'pattern' => '\A\/user\/([^\/.]+)\z',
            'params'  => ['login'],
            'methods' => 8,
            'format'  => '/user/%s'
        },
        '/user/:name:-:surname:' => {
            'levels'     => 2,
            'name'       => 'user__name_surname',
            'format'     => '/user/%s-%s',
            'params'     => ['name', 'surname'],
            'route_path' => {
                'path'       => '',
                'cmd'        => '',
                'controller' => ignore()
            },
            'methods' => 1,
            'pattern' => '\A\/user\/([^\/.]+)\-([^\/.]+)\z'
        },
        '/user/edit' => {
            'levels'     => 2,
            'route_path' => {
                'path' => 'user',
                'cmd'  => 'edit'
            },
            'pattern' => '\A\/user\/edit\z',
            'methods' => 28,
            'params'  => [],
            'format'  => '/user/edit',
            'name'    => 'user__edit'
        }
    },
    'Routes'
);

$wi->routing($r);

$wi->request(get_request(path => '',));

cmp_deeply(
    $r->get_current_route($wi),
    {
        'pattern'    => '\\A\\/\\z',
        'params'     => [],
        'levels'     => 0,
        'methods'    => 1,
        'args'       => {},
        'route_path' => {
            'path' => 'user',
            'cmd'  => 'list'
        },
        'name'   => 'user_defualt',
        'format' => '/',
        'path'   => 'user',
        'cmd'    => 'list'
    },
    'GET "/"'
);

$wi->request(
    get_request(
        path   => '',
        method => 'POST',
    )
);

cmp_deeply($r->get_current_route($wi), {}, 'POST "/" not found');

$wi->request(
    get_request(
        path   => 'user',
        cmd    => 'without_last_slash',
        params => {id => 1},
    )
);

cmp_deeply(
    $r->get_current_route($wi),
    {
        'route_path' => {
            'cmd'  => 'without_last_slash',
            'path' => 'user'
        },
        'pattern' => '\\A\\/user\\/without_last_slash\\z',
        'format'  => '/user/without_last_slash',
        'methods' => 1,
        'levels'  => 2,
        'args'    => {},
        'params'  => [],
        'name'    => 'user__without_last_slash',
        'cmd'     => 'without_last_slash',
        'path'    => 'user'
    },
    'GET "/user/without_last_slash?id=1"'
);

$wi->request(
    get_request(
        path   => 'user',
        cmd    => 'without_last_slash/',
        params => {id => 1},
    )
);

cmp_deeply($r->get_current_route($wi), {}, 'GET "/user/without_last_slash/?id=1"');

$wi->request(
    get_request(
        path   => 'user',
        cmd    => 'with_last_slash',
        params => {id => 1},
    )
);

cmp_deeply($r->get_current_route($wi), {}, 'GET "/user/with_last_slash?id=1"');

$wi->request(
    get_request(
        path   => 'user',
        cmd    => 'with_last_slash/',
        params => {id => 1},
    )
);

cmp_deeply(
    $r->get_current_route($wi),
    {
        'args'       => {},
        'levels'     => 2,
        'methods'    => 1,
        'pattern'    => '\\A\\/user\\/with_last_slash\\/\\z',
        'format'     => '/user/with_last_slash/',
        'name'       => 'user__with_last_slash',
        'route_path' => {
            'path' => 'user',
            'cmd'  => 'with_last_slash'
        },
        'params' => [],
        'path'   => 'user',
        'cmd'    => 'with_last_slash'
    },
    'GET "/user/with_last_slash/?id=1"'
);

$wi->request(
    get_request(
        path   => 'user',
        cmd    => 'add',
        method => 'POST',
    )
);

cmp_deeply(
    $r->get_current_route($wi),
    {
        'format'     => '/user/add',
        'pattern'    => '\\A\\/user\\/add\\z',
        'args'       => {},
        'route_path' => {
            'cmd'  => 'add',
            'path' => 'user'
        },
        'params'  => [],
        'methods' => 4,
        'name'    => 'user__add',
        'levels'  => 2,
        'cmd'     => 'add',
        'path'    => 'user'
    },
    'POST "/user/add"'
);

$wi->request(
    get_request(
        path   => 'user',
        cmd    => 'info*',
        method => 'HEAD',
    )
);

cmp_deeply(
    $r->get_current_route($wi),
    {
        'name'       => 'user__info',
        'args'       => {},
        'pattern'    => '\\A\\/user\\/info\\*\\z',
        'route_path' => {
            'cmd'  => 'info',
            'path' => 'user'
        },
        'levels'  => 2,
        'format'  => '/user/info*',
        'params'  => [],
        'methods' => 127,
        'cmd'     => 'info',
        'path'    => 'user'
    },
    'HEAD "/user/info*"'
);

$wi->request(
    get_request(
        path   => 'user',
        cmd    => 'edit',
        method => 'POST',
        params => {id => 1},
    )
);

cmp_deeply(
    $r->get_current_route($wi),
    {
        'methods'    => 28,
        'args'       => {},
        'params'     => [],
        'format'     => '/user/edit',
        'pattern'    => '\\A\\/user\\/edit\\z',
        'levels'     => 2,
        'name'       => 'user__edit',
        'route_path' => {
            'cmd'  => 'edit',
            'path' => 'user'
        },
        'cmd'  => 'edit',
        'path' => 'user'
    },
    'POST "/user/edit?id=1"'
);

#
# standart placeholders
#

$wi->request(
    get_request(
        path => 'user',
        cmd  => 'standart/vasya',
    )
);

cmp_deeply(
    $r->get_current_route($wi),
    {
        'format'     => '/user/standart/%s',
        'pattern'    => '\\A\\/user\\/standart\\/([^\\/.]+)\\z',
        'args'       => {'name' => 'vasya'},
        'route_path' => {
            'cmd'  => 'standart_name',
            'path' => 'user'
        },
        'params'  => ['name'],
        'methods' => 1,
        'levels'  => 3,
        'name'    => 'user__standart_name',
        'cmd'     => 'standart_name',
        'path'    => 'user'
    },
    'GET "/user/standart/vasya"'
);

$wi->request(
    get_request(
        path => 'user',
        cmd  => 'standart/vasya pupkin',
    )
);

cmp_deeply(
    $r->get_current_route($wi),
    {
        'args'       => {'name' => 'vasya pupkin'},
        'format'     => '/user/standart/%s',
        'levels'     => 3,
        'params'     => ['name'],
        'route_path' => {
            'cmd'  => 'standart_name',
            'path' => 'user'
        },
        'name'    => 'user__standart_name',
        'methods' => 1,
        'pattern' => '\\A\\/user\\/standart\\/([^\\/.]+)\\z',
        'cmd'     => 'standart_name',
        'path'    => 'user'
    },
    'GET "/user/standart/vasya pupkin"'
);

$wi->request(
    get_request(
        path => 'user',
        cmd  => 'standart/vasya.pupkin',
    )
);

cmp_deeply($r->get_current_route($wi), {}, 'GET "/user/standart/vasya.pupkin" not found');

$wi->request(
    get_request(
        path => 'user',
        cmd  => 'standart/vasya/pupkin',
    )
);

cmp_deeply($r->get_current_route($wi), {}, 'GET "/user/standart/vasya/pupkin" not found');

#
# relaxed placeholders
#

$wi->request(
    get_request(
        path => 'user',
        cmd  => 'relaxed/vasya',
    )
);

cmp_deeply(
    $r->get_current_route($wi),
    {
        'methods'    => 1,
        'pattern'    => '\\A\\/user\\/relaxed\\/([^\\/]+)\\z',
        'name'       => 'user__relaxed_name',
        'levels'     => 3,
        'format'     => '/user/relaxed/%s',
        'params'     => ['name'],
        'args'       => {'name' => 'vasya'},
        'route_path' => {
            'cmd'  => 'relaxed_name',
            'path' => 'user'
        },
        'cmd'  => 'relaxed_name',
        'path' => 'user'
    },
    'GET "/user/relaxed/vasya"'
);

$wi->request(
    get_request(
        path => 'user',
        cmd  => 'relaxed/vasya pupkin',
    )
);

cmp_deeply(
    $r->get_current_route($wi),
    {
        'methods'    => 1,
        'route_path' => {
            'cmd'  => 'relaxed_name',
            'path' => 'user'
        },
        'args'    => {'name' => 'vasya pupkin'},
        'params'  => ['name'],
        'pattern' => '\\A\\/user\\/relaxed\\/([^\\/]+)\\z',
        'name'    => 'user__relaxed_name',
        'levels'  => 3,
        'format'  => '/user/relaxed/%s',
        'cmd'     => 'relaxed_name',
        'path'    => 'user'
    },
    'GET "/user/relaxed/vasya pupkin"'
);

$wi->request(
    get_request(
        path => 'user',
        cmd  => 'relaxed/vasya.pupkin',
    )
);

cmp_deeply(
    $r->get_current_route($wi),
    {
        'name'       => 'user__relaxed_name',
        'params'     => ['name'],
        'format'     => '/user/relaxed/%s',
        'args'       => {'name' => 'vasya.pupkin'},
        'pattern'    => '\\A\\/user\\/relaxed\\/([^\\/]+)\\z',
        'levels'     => 3,
        'methods'    => 1,
        'route_path' => {
            'cmd'  => 'relaxed_name',
            'path' => 'user'
        },
        'cmd'  => 'relaxed_name',
        'path' => 'user'
    },
    'GET "/user/relaxed/vasya.pupkin"'
);

$wi->request(
    get_request(
        path => 'user',
        cmd  => 'relaxed/vasya/pupkin',
    )
);

cmp_deeply($r->get_current_route($wi), {}, 'GET "/user/relaxed/vasya/pupkin" not found');

#
# wildcard placeholders
#

$wi->request(
    get_request(
        path => 'user',
        cmd  => 'wildcard/vasya',
    )
);

cmp_deeply(
    $r->get_current_route($wi),
    {
        'args'       => {'name' => 'vasya'},
        'format'     => '/user/wildcard/%s',
        'name'       => 'user__wildcard_name',
        'params'     => ['name'],
        'route_path' => {
            'cmd'  => 'wildcard_name',
            'path' => 'user'
        },
        'pattern' => '\\A\\/user\\/wildcard\\/(.+)\\z',
        'methods' => 1,
        'levels'  => 3,
        'cmd'     => 'wildcard_name',
        'path'    => 'user'
    },
    'GET "/user/wildcard/vasya"'
);

$wi->request(
    get_request(
        path => 'user',
        cmd  => 'wildcard/vasya pupkin',
    )
);

cmp_deeply(
    $r->get_current_route($wi),
    {
        'levels'     => 3,
        'args'       => {'name' => 'vasya pupkin'},
        'format'     => '/user/wildcard/%s',
        'methods'    => 1,
        'params'     => ['name'],
        'pattern'    => '\\A\\/user\\/wildcard\\/(.+)\\z',
        'route_path' => {
            'path' => 'user',
            'cmd'  => 'wildcard_name'
        },
        'name' => 'user__wildcard_name',
        'path' => 'user',
        'cmd'  => 'wildcard_name'
    },
    'GET "/user/wildcard/vasya pupkin"'
);

$wi->request(
    get_request(
        path => 'user',
        cmd  => 'wildcard/vasya.pupkin',
    )
);

cmp_deeply(
    $r->get_current_route($wi),
    {
        'name'       => 'user__wildcard_name',
        'route_path' => {
            'path' => 'user',
            'cmd'  => 'wildcard_name'
        },
        'methods' => 1,
        'args'    => {'name' => 'vasya.pupkin'},
        'pattern' => '\\A\\/user\\/wildcard\\/(.+)\\z',
        'levels'  => 3,
        'format'  => '/user/wildcard/%s',
        'params'  => ['name'],
        'path'    => 'user',
        'cmd'     => 'wildcard_name'
    },
    'GET "/user/wildcard/vasya.pupkin"'
);

$wi->request(
    get_request(
        path => 'user',
        cmd  => 'wildcard/vasya/pupkin',
    )
);

cmp_deeply(
    $r->get_current_route($wi),
    {
        'name'       => 'user__wildcard_name',
        'methods'    => 1,
        'args'       => {'name' => 'vasya/pupkin'},
        'levels'     => 3,
        'params'     => ['name'],
        'pattern'    => '\\A\\/user\\/wildcard\\/(.+)\\z',
        'format'     => '/user/wildcard/%s',
        'route_path' => {
            'path' => 'user',
            'cmd'  => 'wildcard_name'
        },
        'path' => 'user',
        'cmd'  => 'wildcard_name'
    },
    'GET "/user/wildcard/vasya/pupkin"'
);

#
# More placeholders
#

$wi->request(
    get_request(
        path   => 'user',
        cmd    => 'delete/2',
        method => 'POST',
    )
);

cmp_deeply(
    $r->get_current_route($wi),
    {
        'methods' => 4,
        'args'    => {
            'id'     => '2',
            'action' => 'delete'
        },
        'name'       => 'user__action',
        'levels'     => 3,
        'route_path' => {
            'cmd'  => 'action',
            'path' => 'user'
        },
        'params'  => ['action', 'id'],
        'pattern' => '\\A\\/user\\/([^\\/.]+)\\/([^\\/.]+)\\z',
        'format'  => '/user/%s/%s',
        'cmd'     => 'action',
        'path'    => 'user'
    },
    'POST "/user/delete/2"'
);

$wi->request(
    get_request(
        path => 'user',
        cmd  => 'vasya-pupkin',
    )
);

cmp_deeply(
    $r->get_current_route($wi),
    {
        'route_path' => {
            'path'       => '',
            'cmd'        => '',
            'controller' => ignore()
        },
        'params'  => ['name', 'surname'],
        'format'  => '/user/%s-%s',
        'name'    => 'user__name_surname',
        'levels'  => 2,
        'pattern' => '\\A\\/user\\/([^\\/.]+)\\-([^\\/.]+)\\z',
        'args'    => {
            'surname' => 'pupkin',
            'name'    => 'vasya'
        },
        'methods' => 1,
        'path'    => 'user',
        'cmd'     => 'name_surname_vasya'
    },
    'GET "/user/vasya-pupkin"'
);

$wi->request(
    get_request(
        path => 'user',
        cmd  => 'petya-pupkin',
    )
);

cmp_deeply(
    $r->get_current_route($wi),
    {
        'format'     => '/user/%s-%s',
        'pattern'    => '\\A\\/user\\/([^\\/.]+)\\-([^\\/.]+)\\z',
        'route_path' => {
            'path'       => '',
            'cmd'        => '',
            'controller' => ignore()
        },
        'params' => ['name', 'surname'],
        'levels' => 2,
        'args'   => {
            'name'    => 'petya',
            'surname' => 'pupkin'
        },
        'name'    => 'user__name_surname',
        'methods' => 1,
        'path'    => 'user',
        'cmd'     => 'name_surname_petya'
    },
    'GET "/user/petya-pupkin"'
);

#
# conditions
#

# array

$wi->request(
    get_request(
        path   => 'user',
        cmd    => 'fry',
        method => 'PUT',
        params => {name => 'vasya'},
    )
);

cmp_deeply($r->get_current_route($wi), {}, 'PUT "/user/fry" not found');

$wi->request(
    get_request(
        path   => 'user',
        cmd    => 'bender',
        method => 'PUT',
        params => {name => 'vasya'},
    )
);

cmp_deeply(
    $r->get_current_route($wi),
    {
        'args'       => {'login' => 'bender'},
        'pattern'    => '\\A\\/user\\/([^\\/.]+)\\z',
        'route_path' => {
            'path' => 'user',
            'cmd'  => 'bender'
        },
        'methods'    => 8,
        'levels'     => 2,
        'params'     => ['login'],
        'format'     => '/user/%s',
        'conditions' => {'login' => ['bender']},
        'path'       => 'user',
        'cmd'        => 'bender'
    },
    'PUT "/user/bender"'
);

# regexp
$wi->request(
    get_request(
        path => 'user',
        cmd  => 'vasya',
    )
);

cmp_deeply($r->get_current_route($wi), {}, 'GET "/user/vasya" not found');

$wi->request(
    get_request(
        path => 'user',
        cmd  => '1',
    )
);

cmp_deeply(
    $r->get_current_route($wi),
    {
        'format'     => '/user/%s',
        'name'       => 'user__profile',
        'conditions' => {'id' => qr/\A[1-9][0-9]*\z/},
        'pattern'    => '\\A\\/user\\/([^\\/.]+)\\z',
        'methods'    => 1,
        'route_path' => {
            'cmd'  => 'profile',
            'path' => 'user'
        },
        'args'   => {'id' => '1'},
        'params' => ['id'],
        'levels' => 2,
        'cmd'    => 'profile',
        'path'   => 'user'
    },
    'GET "/user/1"'
);

# sub

$wi->request(
    get_request(
        path => 'user',
        cmd  => '1/settings',
    )
);

cmp_deeply($r->get_current_route($wi), {}, 'GET "/user/1/settings" not found');

$wi->request(
    get_request(
        path => 'user',
        cmd  => '1111/settings',
    )
);

cmp_deeply(
    $r->get_current_route($wi),
    {
        'params'     => ['id'],
        'format'     => '/user/%s/settings',
        'route_path' => {
            'path' => 'user',
            'cmd'  => 'settings'
        },
        'levels'     => 3,
        'conditions' => {'id' => ignore()},
        'name'       => 'user__settings',
        'pattern'    => '\\A\\/user\\/([^\\/.]+)\\/settings\\z',
        'methods'    => 1,
        'args'       => {'id' => '1111'},
        'path'       => 'user',
        'cmd'        => 'settings'
    },
    'GET "/user/1111/settings"'
);

# check data from methods Request

$wi->request(
    get_request(
        path   => 'user',
        cmd    => 'scheme',
        scheme => 'http',
    )
);

cmp_deeply($r->get_current_route($wi), {}, 'GET "/user/scheme" not found');

$wi->request(
    get_request(
        path   => 'user',
        cmd    => 'scheme',
        scheme => 'https',
    )
);

cmp_deeply(
    $r->get_current_route($wi),
    {
        'params'     => [],
        'levels'     => 2,
        'format'     => '/user/scheme',
        'pattern'    => '\\A\\/user\\/scheme\\z',
        'conditions' => {'scheme' => qr/https/},
        'methods'    => 1,
        'name'       => 'user__sheme',
        'args'       => {},
        'route_path' => {
            'path' => 'user',
            'cmd'  => 'scheme'
        },
        'path' => 'user',
        'cmd'  => 'scheme'
    },
    'GET "/user/scheme"'
);

# check data from method "http_header" Request

$wi->request(
    get_request(
        path    => 'user',
        cmd     => 'mobile',
        headers => {user_agent => 'Mozilla/5.0 (X11; Linux i586; rv:31.0) Gecko/20100101 Firefox/31.0',}
    )
);

cmp_deeply($r->get_current_route($wi), {}, 'GET "/user/mobile" not found');

$wi->request(
    get_request(
        path    => 'user',
        cmd     => 'mobile',
        headers => {user_agent => 'HTC_Touch_3G Mozilla/4.0 (compatible; MSIE 6.0; Windows CE; IEMobile 7.11)',}
    )
);

cmp_deeply(
    $r->get_current_route($wi),
    {
        'name'       => 'user__mobile',
        'format'     => '/user/mobile',
        'pattern'    => '\\A\\/user\\/mobile\\z',
        'route_path' => {
            'path' => 'user',
            'cmd'  => 'mobile'
        },
        'args'       => {},
        'methods'    => 1,
        'levels'     => 2,
        'params'     => [],
        'conditions' => {'user_agent' => qr/IEMobile/},
        'path'       => 'user',
        'cmd'        => 'mobile'
    },
    'GET "/user/mobile"'
);

#
# url_for
#

is($r->url_for('user__edit'), '/user/edit', 'url_for "user__edit"');

is(
    $r->url_for('user__edit', {}, id => 1, fio => 'vasya pupkin'),
    '/user/edit?fio=vasya%20pupkin&id=1',
    'url_for "user__edit" with params'
  );

is($r->url_for('user__info'), '/user/info*', 'url_for "user__info"');

is($r->url_for('user__name_surname', {name => 'vasya', surname => 'pupkin'},),
    '/user/vasya-pupkin', 'url_for "user__name_surname"');

#
# strictly
#

my $r2 = $wi->new_routing(strictly => FALSE);

$r2->get('/user/without_last_slash')->to(path => 'user', cmd => 'without_last_slash')->name('user__without_last_slash');

$r2->get('/user/with_last_slash/')->to(path => 'user', cmd => 'with_last_slash')->name('user__with_last_slash');

cmp_deeply(
    $r2->{'__ROUTES__'},
    {
        '/user/with_last_slash/' => {
            'levels'     => 2,
            'name'       => 'user__with_last_slash',
            'format'     => '/user/with_last_slash/',
            'route_path' => {
                'cmd'  => 'with_last_slash',
                'path' => 'user'
            },
            'methods' => 1,
            'params'  => [],
            'pattern' => '\A\/user\/with_last_slash\/\z'
        },
        '/user/without_last_slash' => {
            'route_path' => {
                'cmd'  => 'without_last_slash',
                'path' => 'user'
            },
            'params'  => [],
            'pattern' => '\A\/user\/without_last_slash\/\z',
            'methods' => 1,
            'format'  => '/user/without_last_slash/',
            'name'    => 'user__without_last_slash',
            'levels'  => 2
        }
    },
    'Routes strictly => FALSE'
);

$wi->routing($r2);

$wi->request(
    get_request(
        path   => 'user',
        cmd    => 'without_last_slash',
        params => {id => 1},
    )
);

cmp_deeply(
    $r->get_current_route($wi),
    {
        'args'       => {},
        'params'     => [],
        'format'     => '/user/without_last_slash',
        'methods'    => 1,
        'levels'     => 2,
        'route_path' => {
            'cmd'  => 'without_last_slash',
            'path' => 'user'
        },
        'pattern' => '\\A\\/user\\/without_last_slash\\z',
        'name'    => 'user__without_last_slash',
        'cmd'     => 'without_last_slash',
        'path'    => 'user'
    },
    'GET "/user/without_last_slash?id=1"'
);

$wi->request(
    get_request(
        path   => 'user',
        cmd    => 'without_last_slash/',
        params => {id => 1},
    )
);

cmp_deeply(
    $r2->get_current_route($wi),
    {
        'pattern'    => '\\A\\/user\\/without_last_slash\\/\\z',
        'route_path' => {
            'path' => 'user',
            'cmd'  => 'without_last_slash'
        },
        'params'  => [],
        'format'  => '/user/without_last_slash/',
        'args'    => {},
        'levels'  => 2,
        'methods' => 1,
        'name'    => 'user__without_last_slash',
        'path'    => 'user',
        'cmd'     => 'without_last_slash'
    },
    'GET "/user/without_last_slash/?id=1"'
);

$wi->request(
    get_request(
        path   => 'user',
        cmd    => 'with_last_slash',
        params => {id => 1},
    )
);

cmp_deeply(
    $r2->get_current_route($wi),
    {
        'params'     => [],
        'levels'     => 2,
        'pattern'    => '\\A\\/user\\/with_last_slash\\/\\z',
        'format'     => '/user/with_last_slash/',
        'name'       => 'user__with_last_slash',
        'route_path' => {
            'path' => 'user',
            'cmd'  => 'with_last_slash'
        },
        'args'    => {},
        'methods' => 1,
        'path'    => 'user',
        'cmd'     => 'with_last_slash'
    },
    'GET "/user/with_last_slash?id=1"'
);

$wi->request(
    get_request(
        path   => 'user',
        cmd    => 'with_last_slash/',
        params => {id => 1},
    )
);

cmp_deeply(
    $r2->get_current_route($wi),
    {
        'format'     => '/user/with_last_slash/',
        'name'       => 'user__with_last_slash',
        'args'       => {},
        'params'     => [],
        'methods'    => 1,
        'pattern'    => '\\A\\/user\\/with_last_slash\\/\\z',
        'levels'     => 2,
        'route_path' => {
            'path' => 'user',
            'cmd'  => 'with_last_slash'
        },
        'path' => 'user',
        'cmd'  => 'with_last_slash'
    },
    'GET "/user/with_last_slash/?id=1"'
);

is($r2->url_for('user__without_last_slash'), '/user/without_last_slash/', 'url_for "user__without_last_slash"');

is($r2->url_for('user__with_last_slash'), '/user/with_last_slash/', 'url_for "user__with_last_slash"');

#
# under
#

my $player = $r2->under('/player')->to('player#game')->conditions(server_name => sub {$_[1] eq 'Test'});

$player->get('/settings')->to('#settings')->conditions(remote_addr => sub {$_[1] eq '127.0.0.1'});

$r2->get('/test_controller/test_cmd/:param:/:sign:')->to('test_controller#test_cmd');

my $data = '.inputLogin {
    border: medium none;
    outline: medium none;
    padding: 2px;
    width: 200px;
}';

$r2->get('/data/file.css')->to(
    sub {
        my ($controller, %opts) = @_;

        $controller->send_file(content_type => 'text/css', data => $data, filename => 'file.css');
    }
);

cmp_deeply(
    $r2->{'__ROUTES__'},
    {
        '/data/file.css' => {
            'levels'     => 2,
            'methods'    => 1,
            'pattern'    => '\\A\\/data\\/file\\.css\\/\\z',
            'route_path' => {
                'cmd'     => '',
                'path'    => '',
                'handler' => ignore()
            },
            'params' => [],
            'format' => '/data/file.css/'
        },
        '/user/with_last_slash/' => {
            'name'       => 'user__with_last_slash',
            'params'     => [],
            'methods'    => 1,
            'levels'     => 2,
            'route_path' => {
                'path' => 'user',
                'cmd'  => 'with_last_slash'
            },
            'format'  => '/user/with_last_slash/',
            'pattern' => '\A\/user\/with_last_slash\/\z'
        },
        '/user/without_last_slash' => {
            'params'     => [],
            'name'       => 'user__without_last_slash',
            'methods'    => 1,
            'pattern'    => '\A\/user\/without_last_slash\/\z',
            'route_path' => {
                'cmd'  => 'without_last_slash',
                'path' => 'user'
            },
            'format' => '/user/without_last_slash/',
            'levels' => 2
        },
        '/test_controller/test_cmd/:param:/:sign:' => {
            'params'     => ['param', 'sign'],
            'format'     => '/test_controller/test_cmd/%s/%s/',
            'pattern'    => '\\A\\/test_controller\\/test_cmd\\/([^\\/.]+)\\/([^\\/.]+)\\/\\z',
            'route_path' => {
                'path' => 'test_controller',
                'cmd'  => 'test_cmd'
            },
            'levels'  => 4,
            'methods' => 1
        },
        '/player/settings' => {
            'methods'    => 1,
            'params'     => [],
            'conditions' => {
                'remote_addr' => ignore(),
                'server_name' => ignore(),
            },
            'pattern'    => '\A\/player\/settings\/\z',
            'format'     => '/player/settings/',
            'route_path' => ignore(),
            'levels'     => 2
        },
    },
    'Routes player'
);

$wi->routing($r2);

$wi->request(
    get_request(
        path => 'player',
        cmd  => 'settings',
    )
);

cmp_deeply(
    $r2->get_current_route($wi),
    {
        'methods'    => 1,
        'format'     => '/player/settings/',
        'args'       => {},
        'pattern'    => '\\A\\/player\\/settings\\/\\z',
        'route_path' => {
            'controller' => ignore(),
            'path'       => '',
            'cmd'        => ''
        },
        'params'     => [],
        'conditions' => {
            'remote_addr' => ignore(),
            'server_name' => ignore(),
        },
        'levels' => 2,
        'path'   => 'player',
        'cmd'    => 'settings'
    },
    'GET "/player/settings"'
);

{
    no strict 'refs';
    no warnings 'redefine';

    my @packages_having_name2date = grep {defined(&{$_ . '::name2date'})} (map {s'\.pm''; s'/'::'g; $_} keys(%INC)),
      'main';

    *{$_ . '::name2date'} = sub {1423339200}
      foreach @packages_having_name2date;
}

my $sign =
  md5_hex($wi->get_option('salt', '') . int(name2date('today', oformat => 'sec') / 86400) . 'test_controller/test_cmd');

$wi->request(
    get_request(
        path    => 'test_controller',
        cmd     => 'test_cmd/value/' . $sign,
        headers => {'content-type' => '',}
    )
);

$wi->build_response();

cmp_deeply(
    from_json($wi->response->data),
    {param => 'value', sign => '2bccd0d6acc74e3796f6b606f36fe23b'},
    'use sub from controller'
);

$wi->request(
    get_request(
        path    => 'data',
        cmd     => 'file.css/',
        headers => {'content-type' => '',}
    )
);

$wi->build_response();

is($wi->response->data, $data, 'use sub from "to"');

done_testing;
