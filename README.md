# How to listen to your children
Phoenix Perl Monger's October 2018 Presentation
`How to listen to your children`

Looking at how to acheive concurrency in a Perl program and get more information from the children processes instead of simply their exit status.



# Setup
It is assumed that this is run on a Linux type system.  There is no garauntee that this will work on a Windows machine.

## Environmental Variable
`PMP_BASE_DIR` needs to be set to the base dir of this repository so that everything can run

## Server with the healthcheck
Build Image in the server with a healthcheck:
```
docker build -t http_server $PMP_BASE_DIR/http_server
```

To make this interesting we need lots of servers to check on so use the following commands to kick off/stop `$HealthcheckConfig::nodes` instances:

```
$PMP_BASE_DIR/http_server/server_control.pl start
$PMP_BASE_DIR/http_server/server_control.pl stop
```

# Resources
* [fork](https://perldoc.perl.org/functions/fork.html)
* [open](https://perldoc.perl.org/functions/open.html)
* [Using Open for IPC](https://perldoc.perl.org/perlipc.html#Using-open()-for-IPC)
* [Parallel Modules](https://metacpan.org/search?q=parallel)
* [Erik - my debugging buddy](https://github.com/skeletonkey/Erik)
* [Concurrency vs Parallelism](https://medium.com/@deepshig/concurrency-vs-parallelism-4a99abe9efb8)
* [Golang Blog on Concurrency](https://blog.golang.org/concurrency-is-not-parallelism)

  