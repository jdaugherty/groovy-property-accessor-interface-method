package example

import groovy.transform.CompileStatic

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
