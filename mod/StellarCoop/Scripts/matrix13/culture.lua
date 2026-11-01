-- The game's text culture (GetCurrentLanguage) as 'fr' or 'en', the two cultures of quest/text.lua's TEXT and of
-- the talks' lines (matrix13/talks/): French for any French culture, else English.
return function(name) return require('nightop.recruiter_text').culture(name)=='fr' and 'fr' or 'en' end
