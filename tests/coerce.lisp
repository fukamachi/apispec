(defpackage #:apispec/tests/coerce
  (:use #:cl
        #:apispec/coerce
        #:apispec/schema
        #:apispec/validate
        #:rove)
  (:import-from #:local-time
                #:timestamp=
                #:universal-to-timestamp))
(in-package #:apispec/tests/coerce)

(defun aget (alist key)
  (cdr (assoc key alist :test 'equal)))

(deftest coerce-number-tests
  (ok (eql (coerce-data 1 'number) 1))
  (ok (eql (coerce-data 1 'integer) 1))
  (ok (eql (coerce-data 1 'float) 1.0))
  (ok (eql (coerce-data "1" 'integer) 1))
  (ok (eql (coerce-data "1.2" 'float) 1.2))
  (ok (eql (coerce-data "1.2" 'double) '1.2d0)))

(deftest coerce-string-tests
  (ok (equal (coerce-data "a" 'string) "a"))
  (ok (signals (coerce-data #\a 'string)
          'coerce-failed))
  (ok (signals (coerce-data 1 'string)
          'coerce-failed))
  (let ((date (coerce-data "2019-04-15" 'date)))
    (ok (typep date 'local-time:timestamp))
    (ok (= (local-time:timestamp-year date) 2019))
    (ok (= (local-time:timestamp-month date) 4))
    (ok (= (local-time:timestamp-day date) 15))
    (ok (= (local-time:timestamp-hour date) 0))
    (ok (= (local-time:timestamp-minute date) 0))
    (ok (= (local-time:timestamp-second date) 0)))
  (let ((date (coerce-data "2019-04-15T01:02:03+09:00" 'date-time)))
    (ok (typep date 'local-time:timestamp))
    (ok (= (local-time:timestamp-year date) 2019))
    (ok (= (local-time:timestamp-month date) 4))
    (ok (= (local-time:timestamp-day date) 15))
    (ok (= (local-time:timestamp-hour date) 1))
    (ok (= (local-time:timestamp-minute date) 2))
    (ok (= (local-time:timestamp-second date) 3)))
  (ok (eq (coerce-data "true" 'boolean) t))
  (ok (eq (coerce-data "false" 'boolean) nil))
  (ok (eq (coerce-data t 'boolean) t))
  (ok (eq (coerce-data nil 'boolean) nil)))

(deftest coerce-array-tests
  (ok (equalp (coerce-data '(1 2 3) 'array)
              #(1 2 3)))
  (ok (equalp (coerce-data '() 'array)
              #()))
  (ok (signals (coerce-data '(1 2 3) '(array 10))
          'validation-failed))
  (ok (equalp (coerce-data '("1" "-2" "3") '(array :items integer))
              #(1 -2 3))))

(deftest coerce-object-tests
  (ok (equalp (coerce-data '(("name" . "fukamachi")) 'object)
              '(("name" . "fukamachi"))))
  (ok (equalp (coerce-data '(("name" . "fukamachi")) '(object
                                                       (("name" string))))
              '(("name" . "fukamachi"))))
  (ok (signals (coerce-data '(("name" . 1)) '(object
                                              (("name" string))))
          'coerce-failed))
  (ok (equalp (coerce-data '(("hi" . "all"))
                           '(object
                             (("name" string))))
              '(("hi" . "all"))))
  (ok (signals (coerce-data '(("hi" . "all"))
                            '(object
                              (("name" string))
                              :required ("name")))
          'validation-failed))

  (testing "additionalProperties"
    (ok (equal (coerce-data '(("name" . "fukamachi")
                              ("created-at" . "2019-04-30"))
                            '(object
                              (("name" string))
                              :additional-properties t))
               '(("name" . "fukamachi")
                 ("created-at" . "2019-04-30"))))
    (ok (signals (coerce-data '(("name" . "fukamachi")
                                ("created-at" . "2019-04-30"))
                              '(object
                                (("name" string))
                                :additional-properties nil))
            'validation-failed))
    (let ((data (coerce-data '(("name" . "fukamachi")
                               ("created-at" . "2019-04-30"))
                             '(object
                               (("name" string))
                               :additional-properties date))))
      (ok (equal (aget data "name") "fukamachi"))
      (ok (timestamp= (aget data "created-at")
                      (universal-to-timestamp
                       (encode-universal-time 0 0 0 30 4 2019))))
      (ok (= (length data) 2)))
    (ok (equal (coerce-data '(("name" . "fukamachi")
                              ("created-at" . nil))
                            '(object
                              (("name" string))
                              :additional-properties (or date null)))
               '(("name" . "fukamachi")
                 ("created-at" . nil))))))
