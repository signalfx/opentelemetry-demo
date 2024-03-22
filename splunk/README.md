<!-- markdownlint-disable-next-line -->

## Welcome to the OpenTelemetry Astronomy Shop Demo

This repository contains a fork of the OpenTelemetry Astronomy Shop, a microservice-based
distributed system intended to illustrate the implementation of OpenTelemetry in
a near real-world environment. It includes customizations for use with Splunk Observability Cloud.

## Update Docker and Kubernetes Scripts

After synchronizing changes with the upstream repository, the following
command can be used to update the Splunk versions of the docker-compose.yml
and kubernetes/opentelemetry-demo.yaml files, which are optimized for use
with Splunk Observability Cloud:

```bash
./update-demos.sh
```

## Quick start

You can be up and running with the demo in a few minutes. Check out the docs for
your preferred deployment method:

- [Docker](https://lantern.splunk.com/Data_Descriptors/Docker/Setting_up_the_OpenTelemetry_Demo_in_Docker)
- [Kubernetes](https://lantern.splunk.com/Data_Descriptors/Kubernetes/Setting_up_the_OpenTelemetry_Demo_in_Kubernetes)
