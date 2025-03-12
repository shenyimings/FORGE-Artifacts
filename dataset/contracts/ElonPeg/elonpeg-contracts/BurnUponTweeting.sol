// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract BurnUponTweeting is Context, AccessControl {

    using SafeMath for uint256;
    event TwitterBurn(string tweetId, uint256 amountSent, uint256 tweetCount);
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant MARKETING_ROLE = keccak256("MARKETING_ROLE");

    // Burn Percent in 100ths of a Percent. Default is 0.5%
    uint256 public _burnPct = 50;
    uint256 public _tweetCount = 0;
    address public _burnWalletAddress = 0x000000000000000000000000000000000000dEaD;
    address private _token;

    uint256 private _reclaimMaxPct = 2;

    constructor() {
        _setupRole(BURNER_ROLE, _msgSender());
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MARKETING_ROLE, _msgSender());
    }

    function ElonTweeted(string memory tweetId) public {
        require(hasRole(BURNER_ROLE, _msgSender()), "Only the registered Elon tweet APIs can burn");
        uint256 burnableAmount = ERC20(_token).balanceOf(address(this));
        uint256 amountToBurn = calculateBurnPct(burnableAmount);
        _tweetCount += 1;
        if (burnableAmount >= 1) {
          ERC20(_token).transfer(_burnWalletAddress, amountToBurn);
          emit TwitterBurn(tweetId, amountToBurn, _tweetCount);
        }
    }

    function reclaim(address recipient, uint256 amount) public {
        // To keep vault funds in circulation, the Marketing wallet is optionally
        // able to reclaim up to _reclaimMaxPct of Burn Vault funds on every 50th Elon tweet

        require(hasRole(MARKETING_ROLE, _msgSender()), "Only the marketing wallet can reclaim");
        require(_tweetCount.mod(50) == 0, "You can only reclaim every 50 tweets");
        uint256 tokenBalance = ERC20(_token).balanceOf(address(this));
        require(amount <= calculateReclaimMax(tokenBalance), "Reclaim amount too high");
        ERC20(_token).transfer(recipient, amount);
    }

    function setBurnPct(uint256 burnPct) public {
        require(hasRole(BURNER_ROLE, _msgSender()), "Only the registered Elon tweet APIs can burn");
        _burnPct = burnPct;
    }

    function setTokenAddress(address tokenAddr) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Only the registered Elon tweet APIs can burn");
        _token = tokenAddr;
    }

    function calculateBurnPct(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_burnPct).div(10**4);
    }

    function calculateReclaimMax(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_reclaimMaxPct).div(10**2);
    }

    receive() external payable {}
}
