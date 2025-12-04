REPOSITORY_NAME=yovanggaanandhika/laravelpine
TAG_NAME=8.3

default:
	docker buildx build -t ${REPOSITORY_NAME}:${TAG_NAME} --load .

pull:
	docker pull ${REPOSITORY_NAME}:${TAG_NAME}

delete:
	docker rmi ${REPOSITORY_NAME}:${TAG_NAME}

push:
	docker buildx build \
	--platform linux/amd64 \
	-t ${REPOSITORY_NAME}:${TAG_NAME} --progress=plain --push .