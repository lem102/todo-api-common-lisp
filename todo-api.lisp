(defpackage :todo-api
  (:use :cl)
  (:local-nicknames (:h :hunchentoot)
                    (:e :easy-routes)
                    (:u :uuid)
                    (:s :spinneret)
                    (:m :mito)))

(in-package :todo-api)

(m:deftable todo ()
  ((id :col-type :uuid :primary-key t)
   (description :col-type (:varchar 255))
   (status :col-type :boolean))
  (:auto-pk nil)
  (:record-timestamps nil))

(defmacro with-db (&rest body)
  `(let ((mito:*connection* (dbi:connect-cached :postgres
                                                :database-name ,(uiop:getenv "PGDATABASE")
                                                :username ,(uiop:getenv "PGUSER")
                                                :password ,(uiop:getenv "PGPASSWORD"))))
     ,@body))

(defun db-ensure-tables ()
  (with-db
    (m:ensure-table-exists 'todo)))

(setq s:*unvalidated-attribute-prefixes* '("hx-" "data-" "aria-"))

(defparameter *server* (make-instance 'e:routes-acceptor :port 3333))

(defun start ()
  (h:start *server*))

(defun stop ()
  (h:stop *server*))

(e:defroute todo-page-endpoint ("/todo" :method :get) ()
  (render-todo-page))

(e:defroute todo-post-endpoint ("/todo" :method :post) (&post description)
  (render-todo (create-todo description)))

(e:defroute todo-list-endpoint ("/todo/list" :method :get) ()
  (render-todos))

(e:defroute todo-endpoint ("/todo/:id" :method :get) ()
  (render-todo id))

(e:defroute todo-change-status-endpoint ("/todo/:id/change-status" :method :post) ()
  (update-todo-status id)
  (render-todo id))

(e:defroute todo-delete-endpoint ("/todo/:id" :method :delete) ()
  (delete-todo id)
  nil)

(defun render-todo-page ()
  "Produce the html for the todo page."
  (s:with-html-string
    (:doctype)
    (:html
     (:head (:script :src "https://unpkg.com/htmx.org@1.9.12"))
     (:body (:h1 "Todos")
            (:ul :hx-trigger "load"
                 :hx-get "/todo/list"
                 :id "list"
                 "Loading...")
            (:input :name "description")
            (:button :hx-post "/todo"
                     :hx-target "#list"
                     :hx-swap "afterbegin"
                     :hx-include "[name='description']"
                     "create new")))))

(defun create-todo (description)
  "Create a todo item with DESCRIPTION."
  (let ((id (format nil "~a" (u:make-v4-uuid))))
    (with-db
        (m:create-dao 'todo
                      :id id
                      :description description
                      :status nil))
    id))

(defun render-todos ()
  "Create html representation of todos."
  (s:with-html-string
    (dolist (todo (with-db (mito:select-dao 'todo)))
      (:div :hx-trigger "load"
            :hx-get (format nil "/todo/~a" (todo-id todo))
            "Loading..."))))

(defun render-todo (id)
  "Create html representation of todo with given ID."
  (let ((todo (get-todo id)))
    (s:with-html-string
      (:li (format nil
                   "~a : ~a"
                   (if (todo-status todo)
                       "DONE"
                       "TODO")
                   (todo-description todo))
           (:button :hx-post (format nil "/todo/~a/change-status" id)
                    :hx-swap "outerHTML"
                    :hx-target "closest li"
                    "Toggle Status")
           (:button :hx-delete (format nil "/todo/~a" id)
                    :hx-swap "outerHTML"
                    :hx-target "closest li"
                    "Delete")))))

(defun update-todo-status (id)
  "Toggle the status of todo with ID."
  (let ((todo (get-todo id)))
    (setf (todo-status todo)
          (not (todo-status todo)))
    (with-db
      (m:save-dao todo))))

(defun delete-todo (id)
  "Delete the todo with the given ID."
  (with-db
    (mito:delete-by-values 'todo :id id)))

(defun get-todo (id)
  "Get todo with ID from database."
  (with-db
    (mito:find-dao 'todo :id id)))
