# #decision-ready — Decision-ready
Every choice arrives with what it takes to make it.

∀ choices put to the user: ∀ questions {context, alternatives, links}; ∀ options {explanation, own context, pick-if, if-wrong, confidence, source}. decision-ready ∩ {BareOption, HiddenAlternative, MissingPickIf, UnstatedUndoCost, RepeatedContext, UnlinkedQuestion, LeanWhereForbidden} = ∅    -- HARD CONSTRAINT
Applies only where the output puts a choice to the user; elsewhere nothing changes.
Question: context = what's true now; alternatives = the options, plus "not offered: X, because Y"; links = how answering it changes other questions in the same output, naming the other question and its answer by their words, a label only beside them ("moot if you answer A, the herdr client, with SSH + herdr on box").
Option: its explanation; own context = only what differs from the question's context; pick this if = when it's the right one; if wrong = the consequence and how hard it is to undo; confidence {confirmed, probable, uncertain, unknown}; source {research finding, established pattern, user input, domain analogy, LLM inference}.
Code and visuals when they exist or can be made: repo code, captures, diagrams. An option that changes code shows its own diff, against the same base as the other options of its question: with #html, the page rules' diff markup; in markdown, a fenced diff block. Never before and after copies of code.
Lean: each question names the option you'd pick, and why. Mode that excludes Recommendations, Suggestions, Solutions or Opinions: no lean.
Markdown: one block per question, one labelled block per option. #concise trims sentences, never elements.
With #epistemic: one confidence label serves both. With #provenance: one origin serves both. With #downstream: one trace of consequences serves both its orders and if wrong.
With #evaluate: its item × dimension table is the alternatives, and its rejected items are the "not offered". With #assumptions: choices you made stay in its list; only choices put to the user appear here.
With #html: a link that makes a question or option moot is its entry in the page's link list, with the link's sentence as its reason, shown only while the link holds; write no "Links:" text for it. Only a relation nothing on the page can grey out is written as a link.
