// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../IVoucherSVG.sol";
import "../utils/StringConverter.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

// contract QualSVG is IVoucherSVG {
contract QualSVG {
    using StringConverter for uint256;
    using StringConverter for uint128;
    using StringConverter for bytes;

    // function generateSVG(uint256 tokenId) external pure override returns (bytes memory) {
    // }

    function generateSVG(uint256 tokenId) external pure returns (string memory) {
        return
        string(
            abi.encodePacked(
                '<svg width="400px" height="267px" viewBox="0 0 400 267" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">',
                '<g stroke-width="1" fill="none" fill-rule="evenodd" font-family="Arial">',
                _generateBackground(),
                _generateTitle(tokenId),
                // _generateContent(),
                _generateLogo(),
                "</g>",
                "</svg>"
            ));
    }

    function _generateBackground() internal pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '<path d="M13.351.616C7.327 3.029 2.751 7.621.575 13.438L0 14.973v236.774l.779 1.914c2.438 5.991 6.688 10.071 12.839 12.325l1.736.636h184.245c156.271 0 184.469-.056 185.715-.37 5.928-1.496 11.781-6.971 14.111-13.201l.575-1.536V15.351l-.664-1.83c-2.138-5.896-7.414-11.02-13.488-13.101C384.77.05 365.664.009 199.733.018L14.82.028l-1.469.588" fill="#f3940b"/>',
                    '<path d="m.014 7.41.014 7.41.559-1.456C2.816 7.558 7.366 3.013 13.351.616L14.82.028 7.41.014 0 0l.014 7.41m385.3-7.143c.22.142.567.261.77.263 3.367.037 11.248 7.454 12.952 12.189.257.715.571 1.54.698 1.834.136.316.237-2.538.248-7.01L400 0l-7.543.004c-4.969.003-7.407.093-7.143.263m14.295 252.27c-1.376 5.552-8.31 12.204-14.295 13.715-1.246.314-29.444.37-185.715.37H15.354l-1.736-.636c-6.584-2.413-10.089-5.94-13.294-13.383-.215-.498-.292 1.24-.306 6.876L0 267.023h400v-7.61c0-7.557-.041-8.287-.391-6.876" fill="#fbfbe8"/>'
                )
            );
    }

    function _generateTitle(
        uint256 tokenId
    ) internal pure returns (string memory) {
        string memory tokenIdStr = tokenId.toString();
        uint256 tokenIdLeftMargin = 340 - 15 * bytes(tokenIdStr).length;

        return
            string(
                abi.encodePacked(
                    '<g transform="translate(30, 30)" fill="#FFFFFF" fill-rule="nonzero">',
                    '<text font-family="Arial" font-size="24" fill="#565963">',
                    abi.encodePacked(
                        '<tspan x="',
                        tokenIdLeftMargin.toString(),
                        '" y="210"># ',
                        tokenIdStr,
                        "</tspan>"
                    ),
                    "</text>",
                    '<text font-family="Arial" font-weight="bold" font-size="45" fill="#565963"><tspan x="30" y="115">Qualification</tspan></text>',
                    "</g>"
                )
            );
    }

    function _generateLogo() internal pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '<g transform="translate(10, 10)" fill-rule="evenodd">',
                    '<svg viewBox="0 0 7.813 8.353" width="45" height="48.111"><path d="M7.108 3.994a3.129 3.129 0 0 1-3.08 3.123A3.13 3.13 0 1 1 4.047.859a3.129 3.129 0 0 1 3.061 3.135zM1.853 6.152c.042.003.072.005.1.005.26 0 .52-.004.78.001a1.381 1.381 0 0 0 .542-.098 1.389 1.389 0 0 0 .837-.866c.169-.489.328-.981.49-1.472.015-.045.037-.064.087-.063.095.004.266-.001.361.003l.004-.021c.027-.107.072-.256.102-.362l.063-.233h-.403l.018-.022c.046-.053.087-.111.139-.157a.631.631 0 0 1 .431-.15 22.005 22.005 0 0 1 .583.003c.056.001.087-.018.104-.072.03-.092.067-.182.1-.273l.11-.298c-.042-.002-.072-.005-.103-.005-.256 0-.511.006-.766-.002a1.393 1.393 0 0 0-.708.169 1.402 1.402 0 0 0-.658.736c-.023.059-.048.076-.105.073l-.365-.008a39.278 39.278 0 0 1-.17.62h.416c-.042.132-.082.248-.117.366-.015.048-.039.066-.092.065-.246-.003-.492-.002-.739-.003-.017 0-.034-.003-.058-.006l.601-2.009-.623-.004s-.295.986-.431 1.447c-.07.237-.148.473-.2.714-.069.328.147.484.437.479.283-.005.565-.005.847-.007.006 0 .013.004.027.01-.037.111-.081.219-.112.331-.081.292-.325.468-.636.466-.197-.002-.393.001-.59-.001h-.058l-.119.31-.126.333zM4.367 4.7l.042.002c.35 0 .699 0 1.049.002h.048c.042-.124.098-.302.14-.425l.061-.182c-.017-.003-.023-.006-.03-.006-.354 0-.753 0-1.107.003 0 0-.006.025-.013.046-.036.092-.064.187-.096.28l-.094.282z" style="fill:#008cfa"/></svg>',
                    "</g>"
                )
            );
    }

    function _formatValue(
        uint256 value,
        uint8 decimals
    ) private pure returns (bytes memory) {
        return
            value
                .uint2decimal(decimals)
                .trim(decimals - 2)
                .addThousandsSeparator();
    }
}
