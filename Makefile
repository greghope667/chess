release:
	nimble build -d:release -d:danger --debugger:native -d:lto

test:
	nimble test --debugger:native
