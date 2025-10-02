# Utility functions for various tasks

# Screen color picker utility for Wayland/Sway
def color-picker [] {
    echo "In 1 sec you can pick a color!"
    sleep 1sec

    let geometry = (slurp -p)

    let result = (grim -g $geometry -t ppm - | magick - -format '%[pixel:p{0,0}]' txt:-)

    let tokens = (
        $result
        | split row "\n"
        | compact --empty
        | get 1
        | split row " "
        | compact --empty
    )

    echo [[type value]; [RGB ($tokens | get 1 | str replace -ra "[()]" "")] [HEX ($tokens | get 2)] ]
}