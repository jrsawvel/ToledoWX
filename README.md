# ToledoWX (Weather)


Toledo, Ohio area weather information that is pulled from National Weather Serivce XML files and HTML pages.


## Perl

Perl scripts execute in cron at regular intervals. The scripts parse multiple NWS XML files and HTML pages, and the scripts download NWS images. The static HTML files are created on the local server.



### Required Modules

The following pure Perl modules were downloaded and included within the this app's lib directory.

* HTML::Template
* XML::TreePP
* XML::FeedPP
* YAML::Tiny



## jQuery Mobile

ToledoWX Perl scripts create jQuery Mobile HTML pages that allow users to read the information easily on all devices. jQuery Mobile enables the pages to display well on older versions of IE too.
