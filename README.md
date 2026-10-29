# Static compilation calls an interface's accessor instead of the property's own

When an interface declares the setter and getter of a property that a class implements as a Groovy property, static
compilation in Groovy 5 calls the interface's methods with `invokeinterface` when the class is compiled together with
the caller, and the class's own accessors with `invokevirtual` when the class is already compiled. The behaviour is
the same at run time, but the same source compiles to a different class file depending on what else is compiled.

Reproduced with Groovy 5.1.3. Groovy 4.0.33 calls the class's accessors in both cases.

## The difference

```groovy
interface Named {
    void setName(String name)
    String getName()
}

abstract class Base implements Named {
    String name
}

class Impl extends Base {}

@CompileStatic
class Svc {
    String rename() {
        println Util.label()
        Base base = new Impl()
        base.name = 'x'
        base.setName('y')
        base.getName()
    }
}
```

`groovyc-repro.sh` compiles all classes together, and again compiles `Svc` against the other classes compiled:

```
== name accessor calls of Svc.rename, compiled together:
 21: invokeinterface // InterfaceMethod example/Named.setName:(Ljava/lang/String;)V
 32: invokeinterface // InterfaceMethod example/Named.setName:(Ljava/lang/String;)V
 38: invokeinterface // InterfaceMethod example/Named.getName:()Ljava/lang/String;
== name accessor calls of Svc.rename, compiled against the other classes:
 21: invokevirtual // Method example/Impl.setName:(Ljava/lang/String;)V
 30: invokevirtual // Method example/Impl.setName:(Ljava/lang/String;)V
 34: invokevirtual // Method example/Impl.getName:()Ljava/lang/String;
```

## In an incremental build

`demo.sh` runs the same thing through Gradle 9.8.0 with incremental Groovy compilation:

1. a full build, where all classes are compiled together;
2. a change to a method body in `Util`, which `Svc` uses only inside a method body;
3. an incremental build, where Gradle recompiles `Util` and `Svc` against the other classes, already compiled.

With Groovy 5.1.3 the class file of `Svc` changes although `Svc.groovy` did not:

```
Incremental compilation of 2 classes completed in 0.877 secs.

== 4. name accessor calls of Svc.rename, full build:
 21: invokeinterface // InterfaceMethod example/Named.setName:(Ljava/lang/String;)V
 32: invokeinterface // InterfaceMethod example/Named.setName:(Ljava/lang/String;)V
 38: invokeinterface // InterfaceMethod example/Named.getName:()Ljava/lang/String;
== name accessor calls of Svc.rename, incremental build:
 21: invokevirtual // Method example/Impl.setName:(Ljava/lang/String;)V
 30: invokevirtual // Method example/Impl.setName:(Ljava/lang/String;)V
 34: invokevirtual // Method example/Impl.getName:()Ljava/lang/String;
```

## Cause

A property of a class in the compilation unit does not have its accessors yet when static type checking runs.
`StaticTypeCheckingVisitor.findMethod` adds a synthetic accessor for the property when every method it found is
abstract, but after the interface's method. `StaticTypeCheckingSupport.removeCovariantsAndInterfaceEquivalents` only
drops an interface method that comes after the method of a class implementing it, so the interface method stays and
is chosen. A compiled class lists its real accessor first, and the interface method is dropped.

## Fix

Add the synthetic accessor first, where a compiled class has its accessor, so that it is preferred over the interface
method the same way. Both builds then call `Impl.setName` and `Impl.getName`.

## Running it

```
./groovyc-repro.sh    # groovyc alone; needs groovyc on the PATH, or GROOVYC set to a groovyc command
./demo.sh             # Gradle 9.8.0: full build, a method body change in Util, incremental build, then both results
```

Both scripts leave the sources as they found them. The Groovy version is set in `gradle.properties`. To try a fix,
publish a Groovy build with it to the local Maven repository and pass its version, for example
`./demo.sh -PgroovyVersion=5.1.4-SNAPSHOT`.
