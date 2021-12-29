
all: setup test teardown


test:
	# ds-collector over k8s
	cp test-collector-k8s.conf.in /tmp/datastax/test-collector-k8s.conf
	echo "" >> /tmp/datastax/test-collector-k8s.conf
	echo "cqlshUsername=$$(kubectl -n cass-operator get secret cluster1-superuser -o yaml | grep " username" | awk -F" " '{print $$2}' | base64 -d && echo "")" >> /tmp/datastax/test-collector-k8s.conf
	echo "cqlshPassword=$$(kubectl -n cass-operator get secret cluster1-superuser -o yaml | grep " password" | awk -F" " '{print $$2}' | base64 -d && echo "")" >> /tmp/datastax/test-collector-k8s.conf
	./collector/ds-collector -T -f /tmp/datastax/test-collector-k8s.conf -n cluster1-dc1-default-sts-0
	./collector/ds-collector -X -f /tmp/datastax/test-collector-k8s.conf -n cluster1-dc1-default-sts-0
	if ! ls /tmp/datastax/ | grep -q ".tar.gz" ; then echo "Failed to generate artefacts in the K8s cluster " ; ls -l /tmp/datastax/ ; exit 1 ; fi


setup:
	mkdir -p /tmp/datastax && rm -fr /tmp/datastax/*
	# make diagnostics bundle
	cd ../ ; ISSUE="TEST-$$(git rev-parse --abbrev-ref HEAD)--$$(git rev-parse --short HEAD)" make
	tar -xvf ../ds-collector.TEST-*.tar.gz
	rm collector/collector.conf
	cp TEST*_secret.key collector/ || true
	test -f collector/collect-info
	# setup k8s cluster
	wget https://thelastpickle.com/files/2021-01-31-cass_operator/01-kind-config.yaml -O /tmp/datastax/01-kind-config.yaml
	kind create cluster --name ds-collector-cluster-vanilla-k8s --config /tmp/datastax/01-kind-config.yaml
	kubectl create ns cass-operator
	kubectl -n cass-operator apply -f https://thelastpickle.com/files/2021-01-31-cass_operator/02-storageclass-kind.yaml
	kubectl -n cass-operator apply -f https://thelastpickle.com/files/2021-01-31-cass_operator/11-install-cass-operator-v1.1.yaml
	while (! kubectl -n cass-operator get pod | grep -q "cass-operator-") || kubectl -n cass-operator get pod | grep -q "0/1" ; do kubectl -n cass-operator get pod ; echo "waiting 10s…" ; sleep 10 ; done
	kubectl -n cass-operator apply -f https://thelastpickle.com/files/2021-01-31-cass_operator/13-cassandra-cluster-3nodes.yaml
	while (! kubectl -n cass-operator get pod | grep -q "cluster1-dc1-default-sts-0") || kubectl -n cass-operator get pod | grep -q "0/2" || kubectl -n cass-operator get pod | grep -q "1/2" ; do kubectl -n cass-operator get pod ; echo "waiting 60s…" ; sleep 60 ; done


teardown:
	kubectl delete cassdcs --all-namespaces --all
	kubectl delete -f https://thelastpickle.com/files/2021-01-31-cass_operator/11-install-cass-operator-v1.1.yaml
	kind delete cluster --name ds-collector-cluster-vanilla-k8s
