// Runs on the fireplace box's own web page (http://<box>/).
// Swaps the box's built-in button page for the latest remote page from GitHub,
// so the remote and the box share one address: no "secure vs not secure" blocking.
// Add ?native to the address to see the box's original button page instead.
(function () {
  if (location.search.indexOf("native") !== -1) return;
  var url = "https://ddalasta.github.io/firestarter/fireplace-remote.html?t=" + Date.now();
  fetch(url, { cache: "no-store" })
    .then(function (r) { if (!r.ok) throw new Error(r.status); return r.text(); })
    .then(function (html) { document.open(); document.write(html); document.close(); })
    .catch(function () {
      document.body.insertAdjacentHTML("afterbegin",
        '<p style="font:16px sans-serif;padding:12px">Couldn\'t load the remote from the internet. ' +
        'The fireplace buttons below still work.</p>');
    });
})();
