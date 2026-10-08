(ns ai-behaviors.playground
  (:require [ai-behaviors.api :as ab]))

(comment
  (println (ab/augment "hello #Frame"))

  (ab/report "ship it #route")

  (println (ab/augment "#route"))
  (println (ab/explain "#challenge"))

  ;; reuse one context across prompts — building it shells out to git
  (let [ctx (ab/context)]
    (mapv #(ab/report % ctx) ["#Code" "#Review #deep"])))
