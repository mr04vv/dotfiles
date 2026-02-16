{ config, pkgs, ... }:

{
  # Hammerspoon configuration
  home.file.".hammerspoon/init.lua" = {
    force = true;
    text = ''
    hs.window.animationDuration = 0

    units = {
      left50        = { x = 0.00, y = 0.00, w = 0.50, h = 1.00 },
      right50       = { x = 0.50, y = 0.00, w = 0.50, h = 1.00 },
      top50         = { x = 0.00, y = 0.00, w = 1.00, h = 0.50 },
      bot50         = { x = 0.00, y = 0.50, w = 1.00, h = 0.50 },
    }

    windowResizeOrPush = {
      previousRect = {
        -- windowリサイズ後、windowのrectサイズを代入する
        -- geometryインスタンスを引数なしで生成できなかったので初期値として意味はないけど引数を入れている
        up    = hs.geometry.rect(units.top50),
        down  = hs.geometry.rect(units.bot50),
        left  = hs.geometry.rect(units.left50),
        right = hs.geometry.rect(units.right50),
      },
      units = {
        up    = units.top50,
        down  = units.bot50,
        left  = units.left50,
        right = units.right50,
      },
    }

    function windowResizeOrPush:getNextScreen(window, cursor)
      if not window then return nil end
      local nextScreen = nil
      if cursor == 'up' then
        nextScreen = window:screen():toNorth()
      elseif cursor == 'down' then
        nextScreen = window:screen():toSouth()
      elseif cursor == 'left' then
        nextScreen = window:screen():toWest()
      elseif cursor == 'right' then
        nextScreen = window:screen():toEast()
      end
      return nextScreen
    end

    -- ウィンドウサイズをスクリーンの指定箇所50%にリサイズする
    -- 既にリサイズ済みで表示中スクリーンの隣にスクリーンが存在する場合、そのスクリーンに移動する
    function windowResizeOrPush:exec(cursor)
      return function()
        local window = hs.window.focusedWindow()
        if not window then return end
        local nextScreen = self:getNextScreen(window, cursor)

        if (window:frame():equals(self.previousRect[cursor]) and nextScreen ~= nil) then
          window:moveToScreen(nextScreen, false, true) -- リサイズあり、ウィンドウに収まるように上部のディスプレイに移動
        else
          window:moveToUnit(self.units[cursor])
          self.previousRect[cursor] = window:frame()
        end
      end
    end

    -- ウィンドウがフルスクリーン（最大化）状態かを判定
    function isMaximized(window)
      local windowFrame = window:frame()
      local screenFrame = window:screen():frame()
      -- 誤差を許容して判定
      return math.abs(windowFrame.x - screenFrame.x) < 5 and
             math.abs(windowFrame.y - screenFrame.y) < 5 and
             math.abs(windowFrame.w - screenFrame.w) < 5 and
             math.abs(windowFrame.h - screenFrame.h) < 5
    end

    -- フルスクリーンのまま別ディスプレイに移動、または端でフルスクリーン化
    function moveFullscreenToScreen(cursor)
      return function()
        local window = hs.window.focusedWindow()
        if not window then return end

        local nextScreen = windowResizeOrPush:getNextScreen(window, cursor)

        if isMaximized(window) then
          if nextScreen then
            window:moveToScreen(nextScreen, false, true)
            window:maximize()
          end
        else
          -- フルスクリーンでない場合
          if nextScreen == nil then
            -- 端のディスプレイにいる場合はフルスクリーンにする
            local windowFrame = window:frame()
            local expectedUnit = windowResizeOrPush.units[cursor]
            local screenFrame = window:screen():frame()
            local expectedFrame = hs.geometry.rect(
              screenFrame.x + expectedUnit.x * screenFrame.w,
              screenFrame.y + expectedUnit.y * screenFrame.h,
              expectedUnit.w * screenFrame.w,
              expectedUnit.h * screenFrame.h
            )
            -- 既に50%リサイズ済みならフルスクリーンに
            if math.abs(windowFrame.x - expectedFrame.x) < 5 and
               math.abs(windowFrame.y - expectedFrame.y) < 5 and
               math.abs(windowFrame.w - expectedFrame.w) < 5 and
               math.abs(windowFrame.h - expectedFrame.h) < 5 then
              window:maximize()
            else
              windowResizeOrPush:exec(cursor)()
            end
          else
            windowResizeOrPush:exec(cursor)()
          end
        end
      end
    end

    -- windowリサイズ、移動系キーバインド
    mash = { 'cmd', 'alt' }
    hs.hotkey.bind(mash, 'left',   windowResizeOrPush:exec('left'))
    hs.hotkey.bind(mash, 'right',  windowResizeOrPush:exec('right'))
    hs.hotkey.bind(mash, 'up',     moveFullscreenToScreen('up'))
    hs.hotkey.bind(mash, 'down',   moveFullscreenToScreen('down'))
    hs.hotkey.bind(mash, 'return', function()
      local window = hs.window.focusedWindow()
      if window then window:maximize() end
    end)
    '';
  };
}
