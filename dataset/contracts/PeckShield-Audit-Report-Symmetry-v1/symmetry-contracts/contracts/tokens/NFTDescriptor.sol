// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

import "../interfaces/INFTDescriptor.sol";
import "../utils/Initializable.sol";

/* solhint-disable quotes */
contract NFTDescriptor is INFTDescriptor, AccessControlEnumerable, Initializable {
    string private constant LOGO =
        '<path fill-rule="evenodd" clip-rule="evenodd" d="M207.348 468.562H189.757C185.274 468.562 181.639 472.196 181.639 476.679C181.639 479.441 182.914 481.677 184.776 483.1C185.363 483.55 186.181 483.421 186.704 482.898L192.726 476.876C195.191 474.411 198.501 473.976 201.267 474.997C201.961 475.253 202.762 475.155 203.285 474.632L207.936 469.981C208.46 469.457 208.089 468.562 207.348 468.562Z" /><path fill-rule="evenodd" clip-rule="evenodd" d="M186.956 484.299C186.262 484.043 185.461 484.141 184.938 484.664L180.287 489.315C179.763 489.839 180.134 490.735 180.875 490.735H198.466C202.949 490.735 206.584 487.1 206.584 482.617C206.584 479.855 205.308 477.619 203.447 476.196C202.859 475.747 202.042 475.875 201.519 476.398L195.497 482.42C193.032 484.885 189.722 485.32 186.956 484.299Z" /><path fill-rule="evenodd" clip-rule="evenodd" d="M221.001 486.674C221.83 486.91 222.756 487.029 223.778 487.029C224.962 487.029 226.007 486.836 226.91 486.451C227.828 486.051 228.547 485.481 229.065 484.741C229.598 483.985 229.865 483.067 229.865 481.986C229.865 481.29 229.731 480.683 229.465 480.164C229.213 479.631 228.843 479.172 228.354 478.787C227.88 478.402 227.31 478.076 226.643 477.809C225.992 477.543 225.259 477.328 224.444 477.165C224.089 477.106 223.748 477.032 223.422 476.943C223.096 476.839 222.808 476.721 222.556 476.588C222.304 476.439 222.104 476.277 221.956 476.099C221.808 475.921 221.734 475.706 221.734 475.455C221.734 475.173 221.823 474.936 222 474.744C222.178 474.536 222.422 474.381 222.734 474.277C223.059 474.159 223.444 474.099 223.889 474.099C224.318 474.099 224.733 474.166 225.133 474.299C225.548 474.433 225.933 474.625 226.288 474.877C226.658 475.129 226.999 475.447 227.31 475.832L229.643 473.588C229.272 473.026 228.821 472.544 228.287 472.144C227.769 471.745 227.14 471.441 226.399 471.234C225.673 471.011 224.8 470.9 223.778 470.9C223.008 470.9 222.267 471.019 221.556 471.256C220.845 471.478 220.216 471.804 219.668 472.233C219.135 472.648 218.705 473.152 218.379 473.744C218.068 474.322 217.913 474.958 217.913 475.655C217.913 476.306 218.016 476.899 218.224 477.432C218.431 477.95 218.742 478.417 219.157 478.831C219.586 479.231 220.119 479.572 220.756 479.853C221.393 480.135 222.141 480.372 223 480.564C223.311 480.623 223.615 480.698 223.911 480.786C224.207 480.86 224.489 480.957 224.755 481.075C225.022 481.179 225.251 481.297 225.444 481.431C225.636 481.564 225.784 481.719 225.888 481.897C226.007 482.075 226.066 482.275 226.066 482.497C226.066 482.793 225.977 483.045 225.799 483.252C225.622 483.445 225.37 483.593 225.044 483.697C224.718 483.8 224.355 483.852 223.955 483.852C223.156 483.852 222.378 483.682 221.623 483.341C220.882 483.001 220.142 482.334 219.401 481.342L217.113 483.941C217.617 484.578 218.187 485.133 218.824 485.607C219.46 486.066 220.186 486.422 221.001 486.674ZM236.122 486.481L233.814 491.916H237.347L239.391 486.807L244.411 475.01H240.368L238.191 481.253C238.073 481.595 237.96 481.919 237.853 482.226C237.821 482.118 237.785 482.008 237.747 481.897C237.628 481.557 237.502 481.238 237.369 480.942L234.881 475.01H230.86L236.122 486.481ZM246.08 486.807V475.01H249.457L249.531 476.434C249.555 476.401 249.58 476.368 249.606 476.336C249.618 476.321 249.63 476.305 249.642 476.29L249.657 476.272C249.668 476.259 249.679 476.245 249.691 476.232C249.716 476.202 249.742 476.172 249.768 476.143C250.049 475.847 250.36 475.603 250.701 475.41C251.056 475.203 251.419 475.047 251.79 474.944C252.175 474.84 252.56 474.788 252.945 474.788C253.522 474.788 254.048 474.877 254.522 475.055C254.996 475.232 255.411 475.521 255.766 475.921C256 476.174 256.202 476.488 256.371 476.863C256.538 476.601 256.737 476.361 256.966 476.143C257.277 475.847 257.617 475.603 257.988 475.41C258.358 475.203 258.743 475.047 259.143 474.944C259.543 474.84 259.928 474.788 260.298 474.788C261.231 474.788 262.009 474.973 262.631 475.344C263.253 475.699 263.719 476.24 264.03 476.965C264.356 477.691 264.519 478.572 264.519 479.609V486.807H260.942V479.898C260.942 479.424 260.876 479.031 260.742 478.72C260.609 478.409 260.409 478.18 260.143 478.032C259.891 477.869 259.572 477.787 259.187 477.787C258.876 477.787 258.588 477.839 258.321 477.943C258.069 478.046 257.847 478.187 257.654 478.365C257.477 478.543 257.336 478.75 257.232 478.987C257.129 479.224 257.077 479.49 257.077 479.787V486.807H253.5V479.876C253.5 479.431 253.433 479.054 253.3 478.743C253.167 478.432 252.967 478.195 252.7 478.032C252.434 477.869 252.123 477.787 251.767 477.787C251.456 477.787 251.168 477.839 250.901 477.943C250.649 478.046 250.427 478.187 250.234 478.365C250.057 478.543 249.916 478.75 249.812 478.987C249.709 479.224 249.657 479.483 249.657 479.764V486.807H246.08ZM267.45 475.01V486.807H271.026V479.764C271.026 479.483 271.078 479.224 271.182 478.987C271.286 478.75 271.426 478.543 271.604 478.365C271.797 478.187 272.019 478.046 272.27 477.943C272.537 477.839 272.826 477.787 273.137 477.787C273.492 477.787 273.803 477.869 274.07 478.032C274.337 478.195 274.536 478.432 274.67 478.743C274.803 479.054 274.87 479.431 274.87 479.876V486.807H278.446V479.787C278.446 479.49 278.498 479.224 278.602 478.987C278.706 478.75 278.846 478.543 279.024 478.365C279.217 478.187 279.439 478.046 279.691 477.943C279.957 477.839 280.246 477.787 280.557 477.787C280.942 477.787 281.26 477.869 281.512 478.032C281.779 478.18 281.979 478.409 282.112 478.72C282.245 479.031 282.312 479.424 282.312 479.898V486.807H285.889V479.609C285.889 478.572 285.726 477.691 285.4 476.965C285.089 476.24 284.622 475.699 284 475.344C283.378 474.973 282.601 474.788 281.668 474.788C281.297 474.788 280.912 474.84 280.513 474.944C280.113 475.047 279.728 475.203 279.357 475.41C278.987 475.603 278.646 475.847 278.335 476.143C278.106 476.361 277.908 476.601 277.741 476.863C277.571 476.488 277.369 476.174 277.136 475.921C276.78 475.521 276.366 475.232 275.892 475.055C275.418 474.877 274.892 474.788 274.314 474.788C273.929 474.788 273.544 474.84 273.159 474.944C272.789 475.047 272.426 475.203 272.071 475.41C271.73 475.603 271.419 475.847 271.138 476.143C271.054 476.236 270.975 476.333 270.901 476.434L270.826 475.01H267.45ZM294.462 487.029C293.159 487.029 292.026 486.77 291.063 486.251C290.1 485.718 289.352 485 288.819 484.097C288.286 483.178 288.02 482.134 288.02 480.964C288.02 480.061 288.168 479.231 288.464 478.476C288.76 477.721 289.175 477.069 289.708 476.521C290.241 475.958 290.871 475.529 291.596 475.232C292.337 474.921 293.144 474.766 294.018 474.766C294.847 474.766 295.602 474.914 296.284 475.21C296.98 475.506 297.58 475.921 298.083 476.454C298.587 476.987 298.972 477.617 299.238 478.343C299.505 479.068 299.623 479.861 299.594 480.72L299.572 481.675H291.467C291.533 481.937 291.628 482.181 291.752 482.408C292.033 482.882 292.433 483.252 292.951 483.519C293.485 483.785 294.114 483.919 294.84 483.919C295.343 483.919 295.788 483.845 296.173 483.697C296.573 483.549 297.002 483.297 297.461 482.941L299.127 485.296C298.668 485.696 298.179 486.022 297.661 486.274C297.143 486.525 296.61 486.711 296.062 486.829C295.528 486.962 294.995 487.029 294.462 487.029ZM291.663 479.098C291.578 479.273 291.511 479.466 291.461 479.676H296.306V479.653C296.276 479.283 296.158 478.957 295.95 478.676C295.758 478.38 295.499 478.15 295.173 477.987C294.847 477.824 294.477 477.743 294.062 477.743C293.485 477.743 292.988 477.861 292.574 478.098C292.174 478.32 291.87 478.654 291.663 479.098ZM302.836 478.12V486.807H306.39V478.12H308.679V475.01H306.39V472.033H302.836V475.01H300.748V478.12H302.836ZM310.71 486.807V475.01H314.087L314.159 476.806C314.247 476.67 314.341 476.538 314.442 476.41C314.857 475.906 315.338 475.506 315.886 475.21C316.434 474.914 317.019 474.766 317.641 474.766C317.908 474.766 318.152 474.788 318.374 474.833C318.611 474.877 318.826 474.929 319.019 474.988L318.041 478.92C317.878 478.817 317.656 478.735 317.375 478.676C317.108 478.602 316.827 478.565 316.531 478.565C316.205 478.565 315.901 478.624 315.62 478.743C315.338 478.846 315.101 479.002 314.909 479.209C314.716 479.416 314.561 479.661 314.442 479.942C314.339 480.224 314.287 480.542 314.287 480.897V486.807H310.71ZM324.616 486.481L322.308 491.916H325.841L327.885 486.807L332.905 475.01H328.862L326.685 481.253C326.566 481.595 326.454 481.919 326.347 482.226C326.315 482.118 326.279 482.008 326.241 481.897C326.122 481.557 325.996 481.238 325.863 480.942L323.375 475.01H319.354L324.616 486.481Z" />';

    bytes32 private constant SYMBOL_DOMAIN = "SYMBOL";

    bytes32 private constant BACKGROUND_DOMAIN = "BACKGROUND";

    bytes32 private constant RARE_DOMAIN = "RARE";

    uint private constant UNIT = 1e18;

    // reserved storage slots for base contract upgrade in future
    uint[50] private __gap;

    RareEvent[] public rareEvents;

    function initialize(address _admin) external onlyInitializeOnce {
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    function setRareEvents(RareEvent[] memory _events) external onlyRole(DEFAULT_ADMIN_ROLE) {
        delete rareEvents;
        for (uint i = 0; i < _events.length; ++i) {
            rareEvents.push(_events[i]);
        }
    }

    function addRareEvent(RareEvent memory _event) external onlyRole(DEFAULT_ADMIN_ROLE) {
        rareEvents.push(_event);
    }

    function _generateName(TokenURIParams memory _params) internal pure returns (string memory) {
        return string.concat("Symmetry Trading Coupon - $", Strings.toString(_params.value / UNIT));
    }

    function _generateDescription() internal pure returns (string memory) {
        return
            "This NFT represents a trading coupon from Symmetry. The owner of this NFT can apply the coupon with its face value on symmetry.trade and use the value to pay for trading fees. A greek alphabet is randomly assigned to each trading coupon. Try to collect all 24 if you are a collector! There's also a small chance that you can get a rare-looking one. Keep an eye!";
    }

    function _rectColor(uint _salt) internal pure returns (string memory) {
        _salt = _salt % 8;
        if (_salt == 0) {
            return "#FF5A86";
        } else if (_salt == 1) {
            return "#57AAF8";
        } else if (_salt == 2) {
            return "#855CDC";
        } else if (_salt == 3) {
            return "#08C605";
        } else if (_salt == 4) {
            return "#46E1A8";
        } else if (_salt == 5) {
            return "#FFBFCF";
        } else if (_salt == 6) {
            return "#FFEE52";
        } else {
            return "#D4C6FD";
        }
    }

    function _textColor(uint _salt) internal pure returns (string memory) {
        _salt = uint(keccak256(abi.encodePacked(_salt, BACKGROUND_DOMAIN)));
        return _salt % 8 < 4 ? "white" : "black";
    }

    function _rareRate(uint _ts) internal view returns (uint) {
        uint len = rareEvents.length;
        for (uint i = 0; i < len; ++i) {
            if (_ts >= rareEvents[i].start && _ts <= rareEvents[i].end) {
                return rareEvents[i].rate;
            }
        }
        return 500; // 5% by default
    }

    function isRare(uint _salt, uint _ts) public view returns (bool) {
        _salt = uint(keccak256(abi.encodePacked(_salt, RARE_DOMAIN)));
        return _salt % 10000 < _rareRate(_ts);
    }

    function _generateBackground(uint _salt) internal pure returns (string memory) {
        _salt = uint(keccak256(abi.encodePacked(_salt, BACKGROUND_DOMAIN)));
        return string.concat('<rect width="512" height="512" fill="', _rectColor(_salt), '" />');
    }

    function _rareColor(uint _seed) internal pure returns (string memory) {
        _seed = _seed % 56; // 8 * 7
        string memory color1 = _rectColor(_seed / 7); // 0-7
        string memory color2 = _rectColor(_seed / 7 > _seed % 7 ? _seed % 7 : (_seed % 7) + 1); // different from color1
        return string.concat(color1, ";", color2, ";", color1, ";");
    }

    function _rareComponent(
        uint _salt,
        uint _x,
        uint _y,
        string memory _suffix
    ) internal pure returns (string memory image) {
        image = string.concat('<path d="M', Strings.toString(_x), " ", Strings.toString(_y), _suffix, '">');
        image = string.concat(
            image,
            '<animate attributeName="fill" values="',
            _rareColor(uint(keccak256(abi.encodePacked(_salt, _x, _y, _suffix)))),
            '" dur="2s" repeatCount="indefinite" />'
        );
        image = string.concat(image, "</path>");
    }

    function _generateRare(uint _salt) internal pure returns (string memory image) {
        image = '<g opacity="0.3" transform="translate(-104 -104) scale(20)">';
        // pattern 1
        for (uint y = 0; y <= 27; y += 9) {
            for (uint x = (((y / 9) % 2) + 1) * 9; x <= 36; x += 18) {
                image = string.concat(image, _rareComponent(_salt, x, y, "h-9v9Z"));
                image = string.concat(image, _rareComponent(_salt, x, y, "v9h-9Z"));
                image = string.concat(image, _rareComponent(_salt, x, y, "c0 5 -4 9 -9 9c0 -5 4 -9 9 -9"));
            }
        }
        // pattern 2
        for (uint y = 0; y <= 27; y += 9) {
            for (uint x = ((y / 9 + 1) % 2) * 9; x < 36; x += 18) {
                image = string.concat(image, _rareComponent(_salt, x, y, "h9v9Z"));
                image = string.concat(image, _rareComponent(_salt, x, y, "v9h9Z"));
                image = string.concat(image, _rareComponent(_salt, x, y, "c0 5 4 9 9 9c0 -5 -4 -9 -9 -9"));
            }
        }
        image = string.concat(image, "</g>");
    }

    function _generateValue(uint _value) internal pure returns (string memory) {
        return
            string.concat(
                ' <text x="50%" y="24" text-anchor="middle" alignment-baseline="hanging" font-family="Verdana" font-size="64">$',
                Strings.toString(_value / UNIT),
                "</text>"
            );
    }

    function getSymbolNum(uint _salt) public pure returns (uint) {
        return uint(keccak256(abi.encodePacked(_salt, SYMBOL_DOMAIN))) % 24;
    }

    function _generateSymbol(uint _salt) internal pure returns (string memory image) {
        _salt = getSymbolNum(_salt);
        string memory greek;
        string memory greekName;
        uint y;
        if (_salt == 0) {
            greek = unicode"α";
            greekName = "alpha";
            y = 360;
        } else if (_salt == 1) {
            greek = unicode"β";
            greekName = "beta";
            y = 400;
        } else if (_salt == 2) {
            greek = unicode"γ";
            greekName = "gamma";
            y = 400;
        } else if (_salt == 3) {
            greek = unicode"δ";
            greekName = "delta";
            y = 360;
        } else if (_salt == 4) {
            greek = unicode"ε";
            greekName = "epsilon";
            y = 360;
        } else if (_salt == 5) {
            greek = unicode"ζ";
            greekName = "zeta";
            y = 400;
        } else if (_salt == 6) {
            greek = unicode"η";
            greekName = "eta";
            y = 400;
        } else if (_salt == 7) {
            greek = unicode"θ";
            greekName = "theta";
            y = 360;
        } else if (_salt == 8) {
            greek = unicode"ι";
            greekName = "iota";
            y = 360;
        } else if (_salt == 9) {
            greek = unicode"κ";
            greekName = "kappa";
            y = 360;
        } else if (_salt == 10) {
            greek = unicode"λ";
            greekName = "lambda";
            y = 360;
        } else if (_salt == 11) {
            greek = unicode"μ";
            greekName = "mu";
            y = 400;
        } else if (_salt == 12) {
            greek = unicode"ν";
            greekName = "nu";
            y = 360;
        } else if (_salt == 13) {
            greek = unicode"ξ";
            greekName = "xi";
            y = 400;
        } else if (_salt == 14) {
            greek = unicode"ο";
            greekName = "omicron";
            y = 360;
        } else if (_salt == 15) {
            greek = unicode"π";
            greekName = "pi";
            y = 360;
        } else if (_salt == 16) {
            greek = unicode"ρ";
            greekName = "rho";
            y = 400;
        } else if (_salt == 17) {
            greek = unicode"σ";
            greekName = "sigma";
            y = 360;
        } else if (_salt == 18) {
            greek = unicode"τ";
            greekName = "tau";
            y = 360;
        } else if (_salt == 19) {
            greek = unicode"υ";
            greekName = "upsilon";
            y = 360;
        } else if (_salt == 20) {
            greek = unicode"φ";
            greekName = "phi";
            y = 400;
        } else if (_salt == 21) {
            greek = unicode"χ";
            greekName = "chi";
            y = 400;
        } else if (_salt == 22) {
            greek = unicode"ψ";
            greekName = "psi";
            y = 400;
        } else {
            greek = unicode"ω";
            greekName = "omega";
            y = 360;
        }
        image = string.concat('<text x="50%" y="300" text-anchor="middle" font-size="210">', greek, "</text>");
        image = string.concat(
            image,
            '<text x="50%" y="',
            Strings.toString(y),
            '" text-anchor="middle" font-size="36" font-family="Trebuchet MS" font-style="italic" text-decoration="underline">',
            greekName,
            "</text>"
        );
    }

    function _generateBody(TokenURIParams memory _params) internal pure returns (string memory image) {
        image = string.concat(
            '<g fill="',
            _textColor(_params.tokenSalt),
            '" font-family="Arial, sans-serif" letter-spacing="0em" font-weight="bold">'
        );
        image = string.concat(image, LOGO, _generateValue(_params.value), _generateSymbol(_params.tokenSalt));
        image = string.concat(image, "</g>");
    }

    function _generateSVGImage(TokenURIParams memory _params) internal view returns (string memory image) {
        image = '<svg width="512" height="512" viewBox="0 0 512 512" fill="none" xmlns="http://www.w3.org/2000/svg">';
        image = string.concat(image, _generateBackground(_params.tokenSalt));
        if (isRare(_params.tokenSalt, _params.ts)) {
            image = string.concat(image, _generateRare(_params.tokenSalt));
        }
        image = string.concat(image, _generateBody(_params));
        image = string.concat(image, "</svg>");
    }

    function constructTokenURI(TokenURIParams memory _params) public view returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"',
                                _generateName(_params),
                                '", "description":"',
                                _generateDescription(),
                                '", "image": "',
                                "data:image/svg+xml;base64,",
                                Base64.encode(bytes(_generateSVGImage(_params))),
                                '"}'
                            )
                        )
                    )
                )
            );
    }
}
