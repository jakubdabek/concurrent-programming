run:
	GOPATH=$(PWD) go run src/main/*.go $(OPT)

verbose: OPT:=-v
verbose: run

install:
	GOPATH=$(PWD) go install src/main/*.go

build:
	GOPATH=$(PWD) go build src/main/*.go
