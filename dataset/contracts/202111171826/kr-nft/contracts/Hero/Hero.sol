// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "../ExtendERC721.sol";
import "../Interfaces/IHero.sol";

contract Hero is ExtendERC721, IHero {

    using SafeMath for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 private _supplyLimit = 10000;

    constructor() ExtendERC721("Kingdomraids Hero", "KRH") {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
    }

    modifier isMinter() {
        require(
            hasRole(MINTER_ROLE, _msgSender()),
            "Must have breed hero role"
        );
        _;
    }

    function setMinterRole(address to) external onlyOwner {
        _setupRole(MINTER_ROLE, to);
    }

    function getSupplyLimit() public view returns (uint256){
        return _supplyLimit;
    }

    function setSupplyLimit(uint256 _newLimit) public onlyOwner() {
        _supplyLimit = _newLimit;
    }

    function increment() internal returns (uint256){
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        return newTokenId;
    }

    function mintWithSummon(address _to)
        external
        override
        isMinter
        returns (uint256)
    {
        uint256 supply = totalSupply();
        require( supply + 1 <= _supplyLimit, "Exceeds maximum  supply" );
        uint256 _tokenId = increment();
        _mint(_to, _tokenId);
        return _tokenId;
    }

    function mint(address _to)
        external
        override
        onlyOwner()
        returns (uint256)
    {

        uint256 supply = totalSupply();
        require( supply + 1 <= _supplyLimit, "Exceeds maximum  supply" );
        uint256 _tokenId = increment();
        _mint(_to, _tokenId);
        return _tokenId;
    }

    function walletOfOwner(address _owner) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }

        return tokensId;
    }
}
