// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

pragma solidity ^0.8.0;

interface ITokenContract {
    function currentPrice() external view returns (uint256);
    function getProtocol() external view returns (address);
    function initSupply() external view returns (uint256);
    function artist() external view returns (address);
}

contract Gumball is Initializable, ERC721EnumerableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter private _tokenIdTracker;

    // Fee
    uint256 constant public bFee = 25; // 1%
    uint256 constant DIVISOR = 1000;

    // Token
    string public baseTokenURI;
    
    // Protocol
    address public tokenContract;
    string _contractURI;

    mapping (uint256 => int256) public gumballIndex;
    uint256[] public gumballs;

    event Swap(address indexed user, uint256 amount);
    event ExactSwap(address indexed user, uint256[] id);
    event Redeem(address indexed user, uint256[] id);
    event SetBaseURI(string uri);
    event SetContractURI(string uri);

    function initialize(
        string memory name,
        string memory symbol,
        string[] memory _URIs,
        address _tokenContract
    ) public initializer {
        __ERC721_init_unchained(name, symbol);

        baseTokenURI = _URIs[0];
        _contractURI = _URIs[1];
        tokenContract = _tokenContract;
    }

    ////////////////////
    ////// Public //////
    ////////////////////

    function gumballsLength() public view returns (uint256) {
        return gumballs.length;
    }

    /** Returns bal of {GBT} */
    function tokenBal() public view returns (uint256) {
        return IERC20Upgradeable(tokenContract).balanceOf(address(this));
    }

    /** Returns bal of {Gumball} */
    function nftBal() public view returns (uint256) {
        return balanceOf(address(this));
    }

    function contractURI() public view returns (string memory) {
        return _contractURI;
    }

    function currentPrice() public view returns (uint256) {
        return ITokenContract(tokenContract).currentPrice();
    }

    //////////////////////
    ////// External //////
    //////////////////////

    /** @dev Allows user to swap {GBT} for an exact {Gumball} that has already been minted
      * @param id is an array of {Gumball}s the user is swapping for 
    */
    function swapForExact(uint256[] memory id) external nonReentrant {
        require(IERC20Upgradeable(tokenContract).balanceOf(msg.sender) >= enWei(id.length), "Insuffient funds");

        uint256 before = IERC20Upgradeable(tokenContract).balanceOf(address(this));

        for(uint256 i = 0; i < id.length; i ++) {
            require(gumballIndex[id[i]] != -1, "Error");
            _pop(uint256(gumballIndex[id[i]]));
            gumballIndex[id[i]] = -1;
            IERC721Upgradeable(address(this)).transferFrom(address(this), msg.sender, id[i]);
        }
        
        IERC20Upgradeable(tokenContract).safeTransferFrom(msg.sender, address(this), enWei(id.length));
        require(IERC20Upgradeable(tokenContract).balanceOf(address(this)) >= before + enWei(id.length), "Bad Swap");

        emit ExactSwap(msg.sender, id);
    }

    /** @dev Allows the user to swap a quantity of {token} > 1 
      * @param _amount is the number of tokens to mint 
    */
    function swap(uint256 _amount) external nonReentrant {
        require(enETH(_amount) * 1e18 == _amount, "Whole GBTs only");
        require(IERC20Upgradeable(tokenContract).balanceOf(msg.sender) >= enWei(1), "Insuffient funds");

        uint256 before = IERC20Upgradeable(tokenContract).balanceOf(address(this));

        IERC20Upgradeable(tokenContract).safeTransferFrom(msg.sender, address(this), _amount);

        for(uint256 i = 0; i < enETH(_amount); i++) {
            mint(msg.sender);
        }
        require(IERC20Upgradeable(tokenContract).balanceOf(address(this)) >= before + _amount, "Bad Swap");

        emit Swap(msg.sender, _amount);
    }

    /** @dev Allows user to swap their gumball(s) to the contract for a payout of {GBT} 
      * @param _id is an array of ids of the gumball token(s) swapped in
    */
    function redeem(uint256[] memory _id) external nonReentrant {
        require(IERC721Upgradeable(address(this)).balanceOf(msg.sender) >= _id.length, "Insuffient Balance");

        uint256 before = IERC721Upgradeable(address(this)).balanceOf(address(this));
        uint256 burnAmount = enWei(_id.length) * bFee / DIVISOR;
    
        for (uint256 i = 0; i < _id.length; i++) {
            gumballs.push(_id[i]);
            gumballIndex[_id[i]] = int256(gumballs.length - 1);
            IERC721Upgradeable(address(this)).transferFrom(msg.sender, address(this), _id[i]);
        }

        IERC20Upgradeable(tokenContract).safeTransfer(tokenContract, burnAmount);
        IERC20Upgradeable(tokenContract).safeTransfer(msg.sender, enWei(_id.length) - burnAmount);

        require(IERC721Upgradeable(address(this)).balanceOf(address(this)) >= before + _id.length, "Bad Swap");

        emit Redeem(msg.sender, _id);
    }

    /** @dev Allows the protocol to set {baseURI} 
      * @param uri is the updated URI
    */
    function setBaseURI(string memory uri) external {
        require(msg.sender == ITokenContract(tokenContract).artist(), "!Auth");

        baseTokenURI = uri;

        emit SetBaseURI(uri);
    }

    /** @dev Allows the protocol to set {contractURI} 
      * @param uri is the updated URI
    */
    function setContractURI(string memory uri) external {
        require(msg.sender == ITokenContract(tokenContract).artist(), "!Auth");
        _contractURI = uri;

        emit SetContractURI(uri);
    }

    //////////////////////
    ////// Internal //////
    //////////////////////

    function enWei(uint256 _num) internal pure returns(uint256) {
        return _num * 10**18;
    }

    function enETH(uint256 _num) internal pure returns(uint256) {
        return _num / 10**18;
    }

    /** @dev {_tokenIdTracker} counter tracks the id of next NFT
      * @param to mints to address */
    function mint(address to) internal {
        _mint(to, _tokenIdTracker.current());
        _tokenIdTracker.increment();
    }

    /** @dev Internal function to remove an unwanted index from an array */
    function _pop(uint256 _index) internal {
        uint256 tempID;
        uint256 swapID;

        if (gumballs.length > 1 && _index != gumballs.length - 1) {
            tempID = gumballs[_index];
            swapID = gumballs[gumballs.length - 1];
            gumballs[_index] = swapID;
            gumballs[gumballs.length - 1] = tempID;
            gumballIndex[swapID] = int256(_index);

            gumballs.pop();
        } else {
            gumballs.pop();
        }
    }
}