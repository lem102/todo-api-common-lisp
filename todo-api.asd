(asdf:defsystem "todo-api"
    :depends-on ("hunchentoot" "easy-routes" "uuid" "spinneret" "mito")
    :components ((:file "todo-api")))
