Messages = require '../messages'

Messages.setWithPrefix 'codegen',
  DialogueTitle: """
    Generated <%= Messages.getText("codegen.Lang", {lang: lang}) %>
    Code for <%= query.name || "Query" %>
  """
  PrimaryAction: 'Save'
  ChooseLang: 'Choose Language'
  Lang: ({lang}) -> switch lang
    when 'py' then 'Python'
    when 'pl' then 'Perl'
    when 'java' then 'Java'
    when 'rb' then 'Ruby'
    when 'js' then 'JavaScript'
    when 'xml' then 'XML'
    else throw new Error "Unknown language #{ lang }"

