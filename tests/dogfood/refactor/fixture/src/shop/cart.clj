(ns shop.cart)

(def ^:dynamic *log* (atom []))

(defn log! [event & args]
  (swap! *log* conj (into [event] args)))

(defn line-total [{:keys [price qty]}]
  (* price qty))

(defn calc
  "Cart total. Orders of 100 or more get 10% off."
  [items]
  (let [subtotal (reduce + (map line-total items))]
    (if (> subtotal 100)
      (do (log! :discount-applied subtotal)
          (* subtotal 0.9))
      subtotal)))

(defn checkout! [items charge!]
  (log! :checkout-started)
  (let [total (calc items)]
    (charge! total)
    (log! :charged total)
    total))
