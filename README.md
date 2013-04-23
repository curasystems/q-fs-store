q-fs-store
==========

filesystem based package store for packages. used by curasystems/q and curasystems/q-server.

its main purpose is to store binary packages named <sha1>.pkg where the package is a zip file
which contains a .q.listing file with some info. valid packages can be generated using curasystems/q.

it offers functions for writingPackages/readingPackages/retrieving paths.
