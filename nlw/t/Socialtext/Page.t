#!perl
# @COPYRIGHT@
use strict;
use warnings;

use DateTime;
use Test::Socialtext tests => 41;
fixtures( 'admin' );

BEGIN {
    use_ok( 'Socialtext::Page' );
}

use Socialtext::l10n qw(loc);

# XXX: This test doesn't test enough, it was put in place as a
# debugging aid, but should actuall test for real
NAME_TO_ID: {
    my %cases = (
        'hello monKey' => 'hello_monkey',
        'asTro?turf'   => 'astro_turf',
        # FIXME: need utf8 examples
    );

    foreach my $case (keys %cases) {
        is( Socialtext::Page->name_to_id($case), $cases{$case},
            "$case => $cases{$case}" );
    }
}

APPEND: {
    my $hub = new_hub('admin');
    my $page;
    $page = Socialtext::Page->new( hub => $hub )->create(
        title   => 'new page',
        content => 'First Paragraph',
        creator => $hub->current_user,
    );
    ok($page->is_recently_modified(), 'page is recently modified' );
    $page->append('Second Paragraph');
    ok($page->content, "First Paragraph\n---\nSecond Paragraph");
}

RENAME: {
    my $hub = new_hub('admin');
    my $page1 = Socialtext::Page->new( hub => $hub )->create(
        title   => 'My First Page',
        content => 'First Paragraph',
        creator => $hub->current_user,
    );
    my $page2 = Socialtext::Page->new( hub => $hub )->create(
        title   => 'My Second Page',
        content => 'Another paragraph first',
        creator => $hub->current_user,
    );

    my $return = $page1->rename('My Second Page');
    is ($return, 0, 'Should not be able to rename since page with new name exists' );

    $return = $page1->rename('My Renamed Page');
    is ($return, 1, 'Rename should return ok' );
    is ($page1->content, "Page renamed to [My Renamed Page]\n", 'Original page content should point to new page' );
}

RENAME_CLOBBER: {
    my $hub = new_hub('admin');
    my $page1 = Socialtext::Page->new( hub => $hub )->create(
        title   => 'My First Page',
        content => 'First Paragraph',
        creator => $hub->current_user,
    );
    my $page2 = Socialtext::Page->new( hub => $hub )->create(
        title   => 'My Second Page',
        content => 'Another paragraph first',
        creator => $hub->current_user,
    );

    my $return = $page1->rename('My Second Page', 1, 1, 'My Second Page');
    is ($return, 1, 'Return should be ok as existing page should be clobbered' );
    is ($page1->content, "Page renamed to [My Second Page]\n", 'Original page content should point to new page' );

    $page2 = $hub->pages->new_from_name('My Second Page');
    is ($page2->content, "First Paragraph\n", 'Exising page should have content of new page' );
}

RENAME_WITH_OVERLAPPING_IDS: {
    my $hub = new_hub('admin');
    my $page = Socialtext::Page->new( hub => $hub )->create(
        title   => 'I LOVE COWS SO MUCH I COULD SCREAM',
        content => 'COWS LOVE ME',
        creator => $hub->current_user,
    );

    my $new_title = 'I Love Cows So Much I Could SCREAM!!!!!!!';
    my $return    = $page->rename($new_title);
    is( $return, 1, 'Rename of a page where new name has same page_id' );
    is( $page->title,   $new_title );
    is( $page->content, "COWS LOVE ME\n" );
}

PREPEND: {
    my $hub = new_hub('admin');
    my $page;
    $page = Socialtext::Page->new( hub => $hub )->create(
        title   => 'new page',
        content => 'First Paragraph',
        creator => $hub->current_user,
    );
    ok($page->is_recently_modified(), 'page is recently modified' );
    $page->prepend('Second Paragraph');
    ok($page->content, "Second Paragraph\n---\nFirst Paragraph");
}

LOAD_WITH_REVISION: {
    my $hub = new_hub('admin');
    my $page;
    $page = Socialtext::Page->new( hub => $hub )->create(
        title   => 'revision_page',
        content => 'First Paragraph',
        creator => $hub->current_user,
    );
    $page->append('Second Paragraph');
    sleep(2); # need the pause to the engine doesn't simply replace the last version with this one
    $page->store(user => $hub->current_user);
    my @ids = $page->all_revision_ids();
    is (scalar(@ids), 2, 'Number of revisions');
    my $oldPage = Socialtext::Page->new( hub => $hub, id=>'revision_page' );
    $oldPage->load_revision($ids[0]);
    is($oldPage->content,"First Paragraph\n", 'Content matches first revision');
    $oldPage = Socialtext::Page->new( hub => $hub, id=>'revision_page' );
    $oldPage->load_revision($ids[1]);
    is($oldPage->content,"First Paragraph\n\n---\nSecond Paragraph\n", 'Content matches latest revision');
    is($oldPage->content, $page->content, 'Content matches latest revision');
}

IS_RECENTLY_MODIFIED: {
    my $hub = new_hub('admin');
    my $page;
    $page = Socialtext::Page->new( hub => $hub )->create(
        title   => 'new page',
        content => 'new page',
        creator => $hub->current_user,
    );
    ok($page->is_recently_modified(), 'page is recently modified' );

    my $four_hours_ago = DateTime->now->subtract( hours => 4 );
    $page = Socialtext::Page->new( hub => $hub )->create(
        title   => 'new page',
        content => 'new page',
        date    => $four_hours_ago,
        creator => $hub->current_user,
    );
    ok(!$page->is_recently_modified(), 'page is not recently modified' );
    ok( $page->is_recently_modified( 60 * 60 * 5 ),
        'page is recently modified' );
}

SET_TITLE_AND_NAME: {
    my $page = Socialtext::Page->new();
    isa_ok( $page, 'Socialtext::Page' );

    $page->title( 'foo' );
    is( $page->title, 'foo', 'Sets the title right the first time' );

    # Make sure we can override it.  There was a bug where title wouldn't
    # get set by the mutator if it was already set.
    $page->title( 'bar' );
    is( $page->title, 'bar', 'Sets the title right the second time' );

    $page->name( 'Wombat' );
    is( $page->name, 'Wombat', 'Sets the name right the first time' );

    $page->name( 'Jackelope' );
    is( $page->name, 'Jackelope', 'Sets the name right the second time' );
}

# Adapted from a failing test in t/restore-revision.t
CREATE_PAGE: {
    my $hub = new_hub('admin');
    isa_ok( $hub, 'Socialtext::Hub' ) or die;

    my $lyrics = join( "", <DATA> );
    my $page = Socialtext::Page->new( hub => $hub )->create(
        title   => "Uneasy Rider",
        content => $lyrics,
        creator => $hub->current_user,
    );
    isa_ok( $page, "Socialtext::Page" );
    is $page->revision_count, 1,
        'Fresh page has exactly 1 revision id.';
}

MAX_ID_LENGTH: {
    my $hub = new_hub('admin');
    my $page = $hub->pages->new_from_name('Admin Wiki');

    eval {
        my $title = 'x' x 256;
        $page->update(
            subject          => $title,
            content          => 'blah blah',
            original_page_id => $page->id,
            revision         => $page->metadata->Revision,
            user             => $hub->current_user,
        );
    };
    like( $@, qr/Page title is too long/,
          'get the expected exception when the page title is too long (> 255 bytes)' );


    eval {
        my $title = 'x' x 254;
        $title .= chr(22369); # the last character in Singapore
        $page->update(
            subject          => $title,
            content          => 'blah blah',
            original_page_id => $page->id,
            revision         => $page->metadata->Revision,
            user             => $hub->current_user,
        );
    };
    like( $@, qr/Page title is too long/,
          'get the expected exception when the page title is too long - with utf8 (> 255 bytes)' );
}

BAD_PAGE_TITLE: {
    my $class      = 'Socialtext::Page';
    my @bad_titles = (
        "Untitled Page",
        "Untitled ///////////////// Page",
        "&&&& UNtiTleD ///////////////// PaGe",
        "&&&& UNtiTleD ///////////////// PaGe *#\$*@!#*@!#\$*",
        "Untitled_Page",
        "",
    );
    for my $page (@bad_titles) {
        ok(
            $class->is_bad_page_title("Untitled Page"),
            "Invalid title: \"$page\""
        );
    }
    ok( !$class->is_bad_page_title("Cows Are Good"), "OK page title" );
}

INVALID_UTF8: {
    my $hub = new_hub('admin');
    eval {
        my $page = Socialtext::Page->new( hub => $hub )->create(
            title   => 'new page',
            content => "* hello\n** \xdamn\n",
            creator => $hub->current_user,
        );
    };

    ok($@, "Check that our crap UTF8 generates an exception");
}
__DATA__
I was takin' a trip out to LA
Toolin' along in my Chevrolet
Tokin' on a number and diggin' on the radio...
Just as I crossed the Mississippi line
I heard that highway start to whine
And I knew that left rear tire was about to go

Well, the spare was flat and I got uptight
'Cause there wasn't a fillin' station in sight
So I just limped on down the shoulder on the rim
I went as far as I could and when I stopped the car
It was right in front of this little bar
Kind of redneck lookin' joint, called the Dew Drop Inn

Well, I stuffed my hair up under my hat
And told the bartender that I had a flat
And would he be kind enough to give me change for a one
There was one thing I was sure proud to see
There wasn't a soul in the place, 'cept for him and me
And he just looked disgusted and pointed toward the telephone

I called up the station down the road a ways
And he said he wasn't very busy today
And he could have somebody there in just 'bout ten minutes or so
He said now you just stay right where you're at
And I didn't bother tellin' the durn fool
I sure as hell didn't have anyplace else to go

I just ordered up a beer and sat down at the bar
When some guy walked in and said, "Who owns this car?
With the peace sign, the mag wheels and four on the floor?"
Well, he looked at me and I damn near died
And I decided that I'd just wait outside
So I laid a dollar on the bar and headed for the door

Just when I thought I'd get outta there with my skin
These five big dudes come strollin' in
With this one old drunk chick and some fella with green teeth
And I was almost to the door when the biggest one said
"You tip your hat to this lady, son"
And when I did all that hair fell out from underneath

Now the last thing I wanted was to get into a fight
In Jackson, Mississippi on a Saturday night
Especially when there was three of them and only one of me
They all started laughin' and I felt kinda sick
And I knew I'd better think of somethin' pretty quick
So I just reached out and kicked old green-teeth right in the knee

He let out a yell that'd curl your hair
But before he could move, I grabbed me a chair
And said "Watch him folks, 'cause he's a thoroughly dangerous man
Well, you may not know it, but this man's a spy
He's an undercover agent for the FBI
And he's been sent down here to infiltrate the Ku Klux Klan"

He was still bent over, holdin' on to his knee
But everyone else was lookin' and listenin' to me
And I laid it on thicker and heavier as I went
I said "Would you believe this man has gone as far
As tearin' Wallace stickers off the bumpers of cars
And he voted for George McGovern for President"

"He's a friend of them long-haired, hippie type, pinko fags
I betcha he's even got a Commie flag
Tacked up on the wall, inside of his garage
He's a snake in the grass, I tell ya guys
He may look dumb, but that's just a disguise
He's a mastermind in the ways of espionage"

They all started lookin' real suspicious at him
And he jumped up an' said "Now, just wait a minute, Jim
You know he's lyin', I've been livin' here all of my life
I'm a faithful follower of Brother John Birch
And I belong to the Antioch Baptist Church
And I ain't even got a garage, you can call home and ask my wife"

Then he started sayin' somethin' 'bout the way I was dressed
But I didn't wait around to hear the rest
I was too busy movin' and hopin' I didn't run outta luck
And when I hit the ground, I was makin' tracks
And they were just takin' my car down off the jacks
So I threw the man a twenty an' jumped in an' fired that mother up

Mario Andretti woulda sure been proud
Of the way I was movin' when I passed that crowd
Comin' out the door and headin' toward me in a trot
And I guess I shoulda gone ahead and run
But somehow I just couldn't resist the fun
Of chasin' them all just once around the parking lot

Well, they're headin' for their car, but I hit the gas
And spun around and headed them off at the pass
I was slingin' gravel and puttin' a ton of dust in the air
Well, I had 'em all out there steppin' and fetchin'
Like their heads were on fire and their asses was catchin'
But I figured I oughta go ahead an split before the cops got there

When I hit the road I was really wheelin'
Had gravel flyin' and rubber squealin'
And I didn't slow down 'til I was almost to Arkansas
Well, I think I'm gonna re-route my trip
I wonder if anybody'd think I'd flipped
If I went to LA...via Omaha

    -- "Uneasy Rider", Charlie Daniels Band
