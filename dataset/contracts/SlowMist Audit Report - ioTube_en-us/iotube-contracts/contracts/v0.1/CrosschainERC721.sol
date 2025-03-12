// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

contract CrosschainERC721 is ERC721Burnable {
    event MinterSet(address indexed minter);

    modifier onlyMinter() {
        require(minter == msg.sender, "not the minter");
        _;
    }

    ERC721 public coToken;
    address public minter;

    constructor(
        ERC721 _coToken,
        address _minter,
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) {
        coToken = _coToken;
        minter = _minter;
        emit MinterSet(_minter);
    }

    function transferMintership(address _newMinter) public onlyMinter {
        minter = _newMinter;
        emit MinterSet(_newMinter);
    }

    function deposit(uint256 _id) public {
        depositTo(msg.sender, _id);
    }

    function depositTo(address _to, uint256 _id) public {
        require(address(coToken) != address(0), "no co-token");
        coToken.safeTransferFrom(msg.sender, address(this), _id);
        _mint(_to, _id);
    }

    function withdraw(uint256 _id) public {
        withdrawTo(msg.sender, _id);
    }

    function withdrawTo(address _to, uint256 _id) public {
        require(address(coToken) != address(0), "no co-token");
        require(_isApprovedOrOwner(msg.sender, _id), "not owner nor approved");
        _burn(_id);
        coToken.safeTransferFrom(address(this), _to, _id);
    }

    function safeMint(
        address _to,
        uint256 _id,
        bytes memory _data
    ) public onlyMinter {
        _safeMint(_to, _id, _data);
    }
}
