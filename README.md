QBit::WebInterface::Routing
=====

Web routing for QBit application.

## Usage

#### Install:

```
apt-get install libqbit-webinterface-routing-perl
```

#### Require:

```
use base qw(QBit::WebInterface::PSGI QBit::Application); #in MyWebInterface.pm
use QBit::WebInterface::Routing;
```

### Create and use routes:
```
my $wi = MyWebInterface->new();

my $r = $wi->new_routing();
```
It may take one option "strictly" (TRUE - strict match with url (default) or FALSE). Important for last slash!

Methods: get, head, post, put, patch, delete, options create route for this requests. Route must begin with "/". All of the following methods define the settings for this route.
```
$r->get('/'); # GET "/"
```
Method "any" create route for all requests or specified.
```
$r->any('/'); # GET/POST/PUT/... "/"

$r->any([qw(GET PATCH)] => "/"); #only GET and PATCH "/"
```
Placeholders.
  - standart placeholders - :name: ~ ([^\/\\.]+)
  - relaxed placeholders - #name# ~ ([^\/]+)
  - wildcard placeholders - \*name\* ~ (.+)
```
$r->get('/user/:id:'); # GET "/user/123" ~ qr{/user/([^/\.]+)}

$r->get('/user/#login#'); # GET "/user/LOGIN" ~ qr{/user/([^/]+)}

$r->get('/user/*login*'); # GET "/user/LOGIN" ~ qr{/user/(.+)}

$r->get('/user/:name:-:surname:'); # GET "/user/vasya-pupkin"
# special symbols in url. Use double symbols ("#" -> "##")
$r->get('/user/::spec_url##'); # GET "/user/:spec_url#"
```
In Controller you can get this value from %opts
```
sub test_controller : CMD {
    my ($self, %opts) = @_;
    
    ...
}
```
Method "conditions". For placeholders, data from request methods (method, uri, scheme, server_name, server_port, remote_addr, query_string) and variables from method http_header (user_agent, ...)
```
$r->get('/user/:id:')->conditions(id => qr/\A[1-9][0-9]*\z/); # GET "/user/123" but NO for GET "/user/vasya"

$r->get('/user/:login:')->conditions(login => [qw(bender)]); # GET "/user/bender" but NO for GET "/user/vasya"

$r->get('/user/:id:/settings')->conditions(id => sub {
    my ($web_interface, $check_values, $params) = @_;
    # WebInterface [obj], check value [string], all params from url [hash]
    return $check_value == 123
});

$r->get('/user/authorization')->conditions(scheme => qr/https/);

$r->get('/user/mobile')->conditions(user_agent => qr/mobile/);
```
Method "to". Set path and cmd for route.
```
$r->get('/user')->to(path => 'user', cmd => 'list');

$r->get('/user/list')->to('user#list');

$r->get('/user/:login:')->to(controller => sub {
    my ($web_interface, $params) = @_:
    # WebInterface [obj], all params from url [hash]
    if ($params->{'login'} eq 'bender') {
        return ('user', 'settings');
    } esle {
        return ('user', 'list');
    }
});

$r->get('/data/file')->to(sub {
    my ($controller, %opts) = @_;
    
    $controller->send_file();
});
```
Method "name" set name for route
```
$r->get('/user/authorization')->name('authorization');

$r->get('/user/:id:/settings')->name('settings');

$r->get('/user/list')->name('list');
```
Method "url_for" create url by route name
```
$controller->routing->url_for('authorization'); # in controller, result "/user/authorization"

$r->url_for('settings', {id => 123}); # "/user/123/settings"

$r->url_for('list', undef, id => 123); # "/user/list?id=123"
```
Method "under" create new object with parent's settings for all routes
```
my $r = $wi->new_routing();

my $user = $r->under('/user')->to('user#list')->conditions(scheme => qr/^http$/);
$user->get('/list');
$user->post('/add')->to('#add')->name('add');

my $profile = $r->under('/profile')->to('profile#view');

$user->get('/settings')->to('#settings')->name('settings');

$profile->get('/view');
$profile->post('/edit')->to('profile#edit');

$wi->routing($r);

# routes:
# GET "/user/list"
# POST "/user/add"
# GET "/user/settings"
# GET "/profile/view"
# POST "/profile/edit
```
