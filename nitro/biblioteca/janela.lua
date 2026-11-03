-- titulo: Janela de app (modelo)
-- Modelo de app de janela. Salve em nitro/sys ou em /apps.
return {
  title = "Meu App", w = 50, h = 14,
  body = function(self, nitro)
    nitro.put(self.x + 3, self.y + 2, "Ola, Nitro OS!", nitro.colors.text, nitro.colors.panel)
  end,
  onKey = function(self, char, code, nitro)
    return false
  end,
}
