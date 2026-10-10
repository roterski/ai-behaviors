(ns shop.receipt
  (:require [clojure.string :as str]
            [shop.cart :as cart]))

(defn render [items]
  (let [lines (for [{:keys [name qty] :as item} items]
                (str name " x" qty " ... " (cart/line-total item)))
        total (cart/calc items)]
    (str (str/join "\n" lines) "\n" "TOTAL " total)))
