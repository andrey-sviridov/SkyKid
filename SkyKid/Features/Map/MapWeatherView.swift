import SwiftUI
import WebKit
import CoreLocation

// MARK: - MapWeatherView

struct MapWeatherView: View {
    let coordinate: CLLocationCoordinate2D

    var body: some View {
        RadarWebView(coordinate: coordinate)
            .ignoresSafeArea()
            .navigationTitle("Карта погоды")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
}

// MARK: - RadarWebView

struct RadarWebView: UIViewRepresentable {
    let coordinate: CLLocationCoordinate2D

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        let wv  = WKWebView(frame: .zero, configuration: cfg)
        wv.isOpaque   = true
        wv.backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
        wv.scrollView.isScrollEnabled = false
        wv.scrollView.bounces         = false
        wv.loadHTMLString(
            Self.buildHTML(lat: coordinate.latitude, lon: coordinate.longitude),
            baseURL: nil
        )
        return wv
    }

    func updateUIView(_: WKWebView, context: Context) {}

    private static func buildHTML(lat: Double, lon: Double) -> String {
        page
            .replacingOccurrences(of: "%%LAT%%", with: "\(lat)")
            .replacingOccurrences(of: "%%LON%%", with: "\(lon)")
    }

    // MARK: - Embedded map page

    private static let page = """
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
    <style>
    *{box-sizing:border-box;margin:0;padding:0}
    html,body{width:100%;height:100%;overflow:hidden;background:#1c1c1e}
    #map{width:100vw;height:100vh}
    .leaflet-control-attribution,.leaflet-control-zoom{display:none!important}
    #ui{
      position:fixed;bottom:0;left:0;right:0;
      padding:0 16px;
      padding-bottom:max(14px,env(safe-area-inset-bottom));
      display:flex;flex-direction:column;gap:10px;
      pointer-events:none
    }
    #player{
      background:rgba(22,22,24,.88);
      backdrop-filter:blur(22px) saturate(1.8);
      -webkit-backdrop-filter:blur(22px) saturate(1.8);
      border:1px solid rgba(255,255,255,.13);
      border-radius:22px;padding:14px 18px;
      pointer-events:all;display:none
    }
    .ph{display:flex;align-items:center;gap:8px;margin-bottom:10px}
    #tlabel{color:#fff;font:600 17px/1 -apple-system;flex:1}
    #ttype{color:rgba(255,255,255,.42);font:13px -apple-system}
    #sl{
      -webkit-appearance:none;width:100%;height:4px;
      border-radius:2px;background:rgba(255,255,255,.18);
      margin-bottom:14px;cursor:pointer
    }
    #sl::-webkit-slider-thumb{
      -webkit-appearance:none;width:22px;height:22px;
      border-radius:50%;background:#3B9EF8;
      box-shadow:0 2px 10px rgba(59,158,248,.55);
      border:2.5px solid #fff
    }
    #pbtns{display:flex;align-items:center;justify-content:center;gap:20px}
    .pb{
      background:none;border:none;color:#3B9EF8;
      cursor:pointer;padding:4px 8px;border-radius:8px;
      font:600 20px/1 -apple-system
    }
    #pb{font-size:44px!important}
    #chips{
      display:flex;gap:8px;overflow-x:auto;
      scrollbar-width:none;pointer-events:all;
      padding-bottom:2px
    }
    #chips::-webkit-scrollbar{display:none}
    .ch{
      background:rgba(255,255,255,.13);
      backdrop-filter:blur(14px) saturate(1.5);
      -webkit-backdrop-filter:blur(14px) saturate(1.5);
      border:1px solid rgba(255,255,255,.17);
      border-radius:20px;color:rgba(255,255,255,.88);
      font:600 13px -apple-system;
      padding:9px 16px;white-space:nowrap;cursor:pointer;
      transition:all .18s
    }
    .ch.on{background:#3B9EF8;border-color:transparent;color:#fff}
    #emsg{
      background:rgba(22,22,24,.85);
      backdrop-filter:blur(16px);-webkit-backdrop-filter:blur(16px);
      border:1px solid rgba(255,255,255,.1);
      border-radius:14px;
      color:rgba(255,255,255,.5);font:14px -apple-system;
      padding:12px 16px;text-align:center;
      pointer-events:all;display:none
    }
    #lb{
      position:fixed;right:16px;
      background:rgba(22,22,24,.88);
      backdrop-filter:blur(22px);-webkit-backdrop-filter:blur(22px);
      border:1px solid rgba(255,255,255,.13);
      border-radius:50%;width:46px;height:46px;
      display:flex;align-items:center;justify-content:center;
      cursor:pointer;color:#3B9EF8;font-size:18px;
      box-shadow:0 2px 12px rgba(0,0,0,.35);
      transition:transform .14s
    }
    #lb:active{transform:scale(.9)}
    </style>
    </head>
    <body>
    <div id="map"></div>
    <div id="ui">
      <div id="player">
        <div class="ph">
          <span id="tlabel">--:--</span>
          <span id="ttype">история</span>
        </div>
        <input id="sl" type="range" min="0" value="0">
        <div id="pbtns">
          <button class="pb" id="bprev">&#9664;</button>
          <button class="pb" id="pb">&#9654;</button>
          <button class="pb" id="bnext">&#9654;&#9654;</button>
        </div>
      </div>
      <div id="emsg"></div>
      <div id="chips">
        <button class="ch on" data-l="radar">Осадки</button>
        <button class="ch" data-l="satellite">Спутник</button>
      </div>
    </div>
    <button id="lb" title="К местоположению">
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#3B9EF8" stroke-width="2.5" stroke-linecap="round">
        <circle cx="12" cy="12" r="4"/><line x1="12" y1="2" x2="12" y2="6"/>
        <line x1="12" y1="18" x2="12" y2="22"/><line x1="2" y1="12" x2="6" y2="12"/>
        <line x1="18" y1="12" x2="22" y2="12"/>
      </svg>
    </button>
    <script>
    (function(){
      var LAT=%%LAT%%, LON=%%LON%%;

      var map = L.map('map', {
        center: [LAT, LON], zoom: 7,
        zoomControl: false, attributionControl: false
      });

      L.tileLayer(
        'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
        { maxZoom: 19, subdomains: 'abcd' }
      ).addTo(map);

      L.circleMarker([LAT, LON], {
        radius: 8, fillColor: '#3B9EF8', color: '#fff',
        weight: 2.5, opacity: 1, fillOpacity: 1
      }).addTo(map);

      // ------ state ------
      var api = null, frames = [], lyrs = {};
      var pos = 0, playing = false, timer = null, curType = 'radar';

      function posLb() {
        var ui = document.getElementById('ui');
        var lb = document.getElementById('lb');
        var style = window.getComputedStyle(ui);
        lb.style.bottom = (ui.offsetHeight + parseFloat(style.bottom) + 14) + 'px';
      }

      // ------ API ------
      fetch('https://api.rainviewer.com/public/weather-maps.json')
        .then(function(r) { return r.json(); })
        .then(function(d) { api = d; loadL('radar'); })
        .catch(function() {
          showMsg('Ошибка сети. Проверьте интернет-соединение.');
          posLb();
        });

      function loadL(type) {
        curType = type;
        stopPlay();
        Object.values(lyrs).forEach(function(l) { if (map.hasLayer(l)) map.removeLayer(l); });
        lyrs = {};
        if (!api) return;

        if (type === 'radar') {
          frames = (api.radar.past || []).concat(api.radar.nowcast || []);
        } else {
          frames = (api.satellite && api.satellite.infrared) ? api.satellite.infrared : [];
        }

        var player = document.getElementById('player');
        if (frames.length === 0) {
          player.style.display = 'none';
          showMsg('Нет данных для этого слоя');
        } else {
          hideMsg();
          var sl = document.getElementById('sl');
          sl.max = frames.length - 1;
          pos = frames.length - 1;
          sl.value = pos;
          player.style.display = 'block';
          showF(pos);
        }
        posLb();
      }

      function showF(p) {
        if (!api || !frames.length) return;
        pos = ((p % frames.length) + frames.length) % frames.length;
        document.getElementById('sl').value = pos;

        var f = frames[pos];
        var d = new Date(f.time * 1000);
        document.getElementById('tlabel').textContent =
          pad(d.getHours()) + ':' + pad(d.getMinutes());
        document.getElementById('ttype').textContent =
          d > new Date() ? 'прогноз' : 'история';

        Object.values(lyrs).forEach(function(l) { l.setOpacity(0); });

        var key = f.path;
        if (!lyrs[key]) {
          var sfx = curType === 'radar' ? '/2/1_1.png' : '/0/0_0.png';
          lyrs[key] = L.tileLayer(
            api.host + f.path + '/256/{z}/{x}/{y}' + sfx,
            { tileSize: 256, opacity: 0, zIndex: 200 }
          ).addTo(map);
        }
        lyrs[key].setOpacity(0.7);
      }

      function pad(n) { return n.toString().padStart(2, '0'); }
      function showMsg(t) { var e=document.getElementById('emsg'); e.textContent=t; e.style.display='block'; }
      function hideMsg() { document.getElementById('emsg').style.display='none'; }

      function stopPlay() {
        if (!playing) return;
        playing = false;
        clearInterval(timer);
        document.getElementById('pb').innerHTML = '&#9654;';
      }

      document.getElementById('pb').onclick = function() {
        if (playing) {
          stopPlay();
        } else {
          playing = true;
          this.innerHTML = '&#9646;&#9646;';
          timer = setInterval(function() { showF(pos + 1); }, 700);
        }
      };
      document.getElementById('bprev').onclick = function() { stopPlay(); showF(pos - 1); };
      document.getElementById('bnext').onclick = function() { stopPlay(); showF(pos + 1); };
      document.getElementById('sl').oninput   = function() { stopPlay(); showF(parseInt(this.value)); };

      document.querySelectorAll('.ch').forEach(function(c) {
        c.onclick = function() {
          document.querySelectorAll('.ch').forEach(function(x) { x.classList.remove('on'); });
          c.classList.add('on');
          loadL(c.dataset.l);
        };
      });

      document.getElementById('lb').onclick = function() {
        map.setView([LAT, LON], 7, { animate: true, duration: 0.5 });
      };

      window.addEventListener('resize', posLb);
      setTimeout(posLb, 400);
    })();
    </script>
    </body>
    </html>
    """
}
