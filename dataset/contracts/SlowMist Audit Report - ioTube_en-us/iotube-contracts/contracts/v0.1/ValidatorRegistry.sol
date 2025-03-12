// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

contract ValidatorRegistry {
    struct File {
        address validator;
        uint256 genre;
        string uri;
    }
    event Registration(address indexed validator, uint256 indexed genre, string uri);

    mapping(address => File) public files;

    function register(uint256 _genre, string calldata _uri) public {
        files[msg.sender] = File(msg.sender, _genre, _uri);
        emit Registration(msg.sender, _genre, _uri);
    }

    function getFile(address _validator) public view returns (uint256, string memory) {
        File storage r = files[_validator];
        return (r.genre, r.uri);
    }
}
