run:
	GOPATH=$(PWD) go run src/main/*.go $(OPT)

verbose: OPT:=-v
verbose: run

install:
	GOPATH=$(PWD) go install src/main/*.go

build:
	GOPATH=$(PWD) go build src/main/*.go

format:
	find -name '*.go' | xargs -t --max-lines=1 go fmt

clean:
	$(RM) Main
