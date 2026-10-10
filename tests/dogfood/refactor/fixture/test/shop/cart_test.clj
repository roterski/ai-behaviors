(ns shop.cart-test
  (:require [clojure.test :refer [deftest is]]
            [shop.cart :as cart]))

(def small [{:name "pen" :price 5 :qty 2}])
(def large [{:name "chair" :price 60 :qty 2}])

(deftest calc-without-discount
  (is (= 10 (cart/calc small))))

(deftest calc-with-discount
  (is (= 108.0 (cart/calc large))))

(deftest checkout-charges-the-total
  (binding [cart/*log* (atom [])]
    (let [charged (atom nil)]
      (cart/checkout! large #(reset! charged %))
      (is (= 108.0 @charged))
      (is (= #{:checkout-started :discount-applied :charged}
             (set (map first @cart/*log*)))))))
