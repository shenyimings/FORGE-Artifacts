//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/Strings.sol";

library SVG {
    function textShadow(string memory txt, string memory bg) internal pure returns (bytes memory) {
        if(bytes(bg).length == 0) bg = "#09f";
        return abi.encodePacked(
            '<svg width="700" height="300" xmlns="http://www.w3.org/2000/svg"><rect width="100%" height="100%" style="fill:',
            bg,
            '"/><g style="dominant-baseline:middle;text-anchor:middle;font-size:200;font-weight:bold;"><defs><filter id="shadow"><feGaussianBlur stdDeviation="2 2" result="shadow"/><feOffset dx="6" dy="6"/></filter></defs><text x="50%" y="54%" style="filter:url(#shadow);fill:black">',
            txt,
            '</text><text x="50%" y="54%" style="fill:white">',
            txt,
            "</text></g></svg>"
        );
    }

    function text(string memory txt, string memory bg) internal pure returns (bytes memory) {
        if(bytes(bg).length == 0) bg = "#09f";
        return abi.encodePacked(
            '<svg width="700" height="300" xmlns="http://www.w3.org/2000/svg"><rect width="100%" height="100%" fill="',
            bg,
            '"/><text x="50%" y="50%" dominant-baseline="middle" text-anchor="middle" font-size="200" fill="white">',
            txt,
            "</text></svg>"
        );
    }

    function texts(string[] memory txts, string memory bg) internal pure returns (bytes memory) {
        if(bytes(bg).length == 0) bg = "#09f";
        uint256 len = txts.length;
        string memory lines = "";
        for (uint256 index = 0; index < len; index++) {
            lines = string(abi.encodePacked(
                lines, 
                '<tspan dy="30" x="10">',
                txts[index],
                '</tspan>'
            ));
        }
        return abi.encodePacked(
            '<svg width="700" height="',
            Strings.toString((txts.length * 30) + 20),
            '" xmlns="http://www.w3.org/2000/svg"><rect width="100%" height="100%" fill="',
            bg,
            '"/><text style="fill: white; font-size: 20px;">',
            lines,
            "</text></svg>"
        );
    }
}