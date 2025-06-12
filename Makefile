# VERSION defines the version for the docker containers.
# To build a specific set of containers with a version,
# you can use the VERSION as an arg of the docker build command (e.g make docker VERSION=0.0.2)
VERSION ?= v0.0.1

# REGISTRY defines the registry where we store our images.
# To push to a specific registry,
# you can use the REGISTRY as an arg of the docker build command (e.g make docker REGISTRY=my_registry.com/username)
# You may also change the default value if you are using a different registry as a default
# REGISTRY ?= registry.gitlab.com/laravel-in-kubernetes/laravel-app
REGISTRY ?= denniskainga/laravel-app

# Commands
docker: docker-build docker-push

docker-build:
	docker build . --target cli -t ${REGISTRY}_cli:${VERSION}
	docker build . --target fpm_server -t ${REGISTRY}_fpm_server:${VERSION}
	docker build . --target nginx_server -t ${REGISTRY}_nginx_server:${VERSION}
	docker build . --target beanstalkd -t ${REGISTRY}_beanstalkd:${VERSION}

docker-push:
	docker push ${REGISTRY}_cli:${VERSION}
	docker push ${REGISTRY}_fpm_server:${VERSION}
	docker push ${REGISTRY}_nginx_server:${VERSION}
	docker push ${REGISTRY}_beanstalkd:${VERSION}

test-db-migration:
	php artisan db:wipe --env=testing && php artisan migrate --env=testing && php artisan migrate:refresh --env=testing
