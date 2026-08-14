{pkgs, ...}: {
  # rqbit in place of aria2: torrent-only, where aria2 also spoke HTTP/FTP.
  # Nothing here used it for those, and curl covers plain HTTP.
  environment.systemPackages = [pkgs.rqbit];
}
