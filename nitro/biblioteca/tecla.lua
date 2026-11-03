-- titulo: Tratar teclas
-- Dentro de onKey(self, char, code, nitro). Retorne true se tratou a tecla.
if code == 200 then       -- seta para cima
  -- faca algo
  return true
elseif code == 208 then   -- seta para baixo
  return true
elseif code == 28 then    -- Enter
  return true
elseif char == 43 then    -- sinal de +
  return true
end
return false
