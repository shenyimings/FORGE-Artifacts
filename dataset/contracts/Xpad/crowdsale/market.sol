// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./Ownable.sol";
import "./IERC20.sol";
import "./Pausable.sol";
import "./SafeMath.sol";

contract crowdsale is Ownable, Pausable {
    using SafeMath for uint256;

    IERC20 public XPADToken;
    IERC20 public USDToken;

    address public USDRecipient;

    struct Vesting {
        uint256 startTimeVesting;
        uint256 vestingDays;
        uint256 value;
        uint256 claimed;
    }
    struct Round {
        uint256 vesting;
        uint256 price;
        uint256 priveDiv;
        uint256 maxTotalAmount;
    }
    
    struct salesInfo {
        bool pause;
        uint256 minUSD;
        uint256 totalSold;
        address addressUSD;
        Round[] allRounds;
        mapping(address => Vesting[]) addressToS;
    }
    mapping(address => salesInfo) internal salesToken;
    address[] public allSalesToken;

    event saleEvent(address tokenAddress, uint256 totalSold);

    constructor(address _USDTokenAddress, address _XPADTokenAddress, address _USDRecipient) {
        pause();
        USDRecipient = _USDRecipient;
        XPADToken = IERC20(_XPADTokenAddress);
        USDToken = IERC20(_USDTokenAddress);

        salesToken[_XPADTokenAddress].allRounds.push(Round(0, 5, 100, 19000000 ether));
        salesToken[_XPADTokenAddress].allRounds.push(Round(120, 5, 100, 19000000 ether));
        salesToken[_XPADTokenAddress].allRounds.push(Round(90, 7, 100, 38000000 ether));
        salesToken[_XPADTokenAddress].allRounds.push(Round(60, 10, 100, 38000000 ether));
        salesToken[_XPADTokenAddress].allRounds.push(Round(30, 15, 100, 38000000 ether));
        salesToken[_XPADTokenAddress].minUSD = 100 ether;
        salesToken[_XPADTokenAddress].pause = false;
        salesToken[_XPADTokenAddress].addressUSD = _USDTokenAddress;
        allSalesToken.push(_XPADTokenAddress);
    }


    function getSaleInfo(address _tokenAddress) public view returns (bool, uint256, uint256, address) {
        return (salesToken[_tokenAddress].pause, salesToken[_tokenAddress].minUSD, salesToken[_tokenAddress].totalSold, salesToken[_tokenAddress].addressUSD);
    }

    function getRound(address _tokenAddress) public view returns (uint) {
        uint256 _totalSoldRound = 0;
        for (uint256 i = 0; i < salesToken[_tokenAddress].allRounds.length; i++) {
            _totalSoldRound = _totalSoldRound.add(salesToken[_tokenAddress].allRounds[i].maxTotalAmount);
            if (salesToken[_tokenAddress].totalSold < _totalSoldRound) {
                return i;
            }
        }
        return 0;
    }

    function getAllRounds(address _tokenAddress) public view returns (Round[] memory) {
        return salesToken[_tokenAddress].allRounds;
    }

    function getAllVesting(address _tokenAddress) public view returns (Vesting[] memory) {
        return salesToken[_tokenAddress].addressToS[msg.sender];
    }

    function getCurrentMaxTotalAmount(address _tokenAddress) internal view returns (uint) {
        uint256 _totalSoldRound = 0;
        for (uint256 i = 0; i < salesToken[_tokenAddress].allRounds.length; i++) {
            _totalSoldRound = _totalSoldRound.add(salesToken[_tokenAddress].allRounds[i].maxTotalAmount);
            if (salesToken[_tokenAddress].totalSold < _totalSoldRound) {
                return _totalSoldRound;
            }
        }
        return 0;
    }

    function sale(address _tokenAddress, uint256 amount) public whenNotPaused {  
        require(salesToken[_tokenAddress].pause == true, "sale suspended");
        uint256 amountUSD;
        uint256 _round = getRound(_tokenAddress);
        uint256 _maxAmount = getCurrentMaxTotalAmount(_tokenAddress) - salesToken[_tokenAddress].totalSold;

        if (amount > _maxAmount) {
            amount = _maxAmount;
            amountUSD = amount.mul(salesToken[_tokenAddress].allRounds[_round].price).div(salesToken[_tokenAddress].allRounds[_round].priveDiv);
        } else {
            amountUSD = amount.mul(salesToken[_tokenAddress].allRounds[_round].price).div(salesToken[_tokenAddress].allRounds[_round].priveDiv);
            require(amountUSD >= salesToken[_tokenAddress].minUSD, "The minimum purchase amount for the XPAD token");
        }

        salesToken[_tokenAddress].addressToS[msg.sender].push(Vesting(block.timestamp, salesToken[_tokenAddress].allRounds[_round].vesting, amount, 0));
        salesToken[_tokenAddress].totalSold = salesToken[_tokenAddress].totalSold.add(amount);
        IERC20(salesToken[_tokenAddress].addressUSD).transferFrom(msg.sender, USDRecipient, amountUSD);
        emit saleEvent(_tokenAddress, salesToken[_tokenAddress].totalSold);
    }

    function claim(address _tokenAddress) public {
        uint256 _climAmount;

        for (uint256 i = 0; i < salesToken[_tokenAddress].addressToS[msg.sender].length; i++) {
            uint256 _totalTime = block.timestamp.sub(salesToken[_tokenAddress].addressToS[msg.sender][i].startTimeVesting);
            uint256 _roundClaimAmount;
            if (_totalTime >= salesToken[_tokenAddress].addressToS[msg.sender][i].vestingDays.mul(86400)) {
                _roundClaimAmount = salesToken[_tokenAddress].addressToS[msg.sender][i].value;
            } else {
                if (salesToken[_tokenAddress].addressToS[msg.sender][i].vestingDays < 30) {
                    _roundClaimAmount = 0;
                } else {
                    _roundClaimAmount = salesToken[_tokenAddress].addressToS[msg.sender][i].value.mul(_totalTime.div(2592000)).div(salesToken[_tokenAddress].addressToS[msg.sender][i].vestingDays.div(30));
                }
            }
            _climAmount = _climAmount.add(_roundClaimAmount).sub(salesToken[_tokenAddress].addressToS[msg.sender][i].claimed);
            salesToken[_tokenAddress].addressToS[msg.sender][i].claimed = _roundClaimAmount;
        }

        require(_climAmount > 0, "Available for claim 0 XPP");
        IERC20(_tokenAddress).transfer(msg.sender, _climAmount);
    }

    function getClaimAmount(address _tokenAddress) public view returns (uint) {
        uint256 _climAmount;

        for (uint256 i = 0; i < salesToken[_tokenAddress].addressToS[msg.sender].length; i++) {
            uint256 _totalTime = block.timestamp.sub(salesToken[_tokenAddress].addressToS[msg.sender][i].startTimeVesting);
            uint256 _roundClaimAmount;
            if (_totalTime >= salesToken[_tokenAddress].addressToS[msg.sender][i].vestingDays.mul(86400)) {
                _roundClaimAmount = salesToken[_tokenAddress].addressToS[msg.sender][i].value;
            } else {
                if (salesToken[_tokenAddress].addressToS[msg.sender][i].vestingDays < 30) {
                    _roundClaimAmount = 0;
                } else {
                    _roundClaimAmount = salesToken[_tokenAddress].addressToS[msg.sender][i].value.mul(_totalTime.div(2592000)).div(salesToken[_tokenAddress].addressToS[msg.sender][i].vestingDays.div(30));
                }
            }
            _climAmount = _climAmount.add(_roundClaimAmount).sub(salesToken[_tokenAddress].addressToS[msg.sender][i].claimed);
        }
        return _climAmount;
    }

    function getTotalClaimAmount(address _tokenAddress) public view returns (uint) {
        uint256 _climAmount;
        for (uint256 i = 0; i < salesToken[_tokenAddress].addressToS[msg.sender].length; i++) {
            _climAmount = _climAmount.add(salesToken[_tokenAddress].addressToS[msg.sender][i].value).sub(salesToken[_tokenAddress].addressToS[msg.sender][i].claimed);
        }
        return _climAmount;
    }

    // only owner functions

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function pauseTokenSale(address _tokenAddress) public onlyOwner {
        salesToken[_tokenAddress].pause = false;
    }

    function unpauseTokenSale(address _tokenAddress) public onlyOwner {
        salesToken[_tokenAddress].pause = true;
    }

    function addTokenSale(address _tokenAddress, uint256 _minUSD, address _addressUSD) public onlyOwner {
        require(salesToken[_tokenAddress].addressUSD == address(0), "this token is already being sold");
        salesToken[_tokenAddress].pause = false;
        salesToken[_tokenAddress].minUSD = _minUSD;
        salesToken[_tokenAddress].addressUSD = _addressUSD;
        allSalesToken.push(_tokenAddress);
    }

    function changeTokenSale(address _tokenAddress, uint256 _minUSD, address _addressUSD) public onlyOwner {
        require(salesToken[_tokenAddress].addressUSD != address(0), "this token is not for sale yet");
        salesToken[_tokenAddress].minUSD = _minUSD;
        salesToken[_tokenAddress].addressUSD = _addressUSD;
    }

    function changeRound(address _tokenAddress, uint256 i, uint256 _vesting, uint256 _price, uint256 _priceDiv, uint256 _maxTotalAmount) public onlyOwner {
        salesToken[_tokenAddress].allRounds[i] = Round(_vesting, _price, _priceDiv, _maxTotalAmount);
    }

    function addRound(address _tokenAddress, uint256 index, uint256 vesting, uint256 price, uint256 _priceDiv, uint256 maxTotalAmount) public onlyOwner {
        require(index >= 0 && index <= salesToken[_tokenAddress].allRounds.length, "Invalid index");

        if (salesToken[_tokenAddress].allRounds.length == 0) {
            salesToken[_tokenAddress].allRounds.push(Round(vesting, price, _priceDiv, maxTotalAmount));
        } else {
            salesToken[_tokenAddress].allRounds.push(salesToken[_tokenAddress].allRounds[salesToken[_tokenAddress].allRounds.length.sub(1)]);
            for (uint256 i = salesToken[_tokenAddress].allRounds.length.sub(1); i > index; i--) {
                uint256 prevIndex = i - 1;
                salesToken[_tokenAddress].allRounds[i] = salesToken[_tokenAddress].allRounds[prevIndex];
            }
            salesToken[_tokenAddress].allRounds[index] = Round(vesting, price, _priceDiv, maxTotalAmount);
        }
    }

    function deleteRound(address _tokenAddress, uint256 _i) public onlyOwner {
        for (uint256 i = _i; i < salesToken[_tokenAddress].allRounds.length; i++) {
            if (i.add(1) < salesToken[_tokenAddress].allRounds.length) {
                salesToken[_tokenAddress].allRounds[i] = salesToken[_tokenAddress].allRounds[i.add(1)];
            }
        }
        salesToken[_tokenAddress].allRounds.pop();
    }

    function setTotalSold(address _tokenAddress, uint256 _totalSold) public onlyOwner {
        salesToken[_tokenAddress].totalSold = _totalSold;
    }

    function setUSDRecipient(address _address) public onlyOwner {
        USDRecipient = _address;
    }

    function withdraw(address _tokenAddress, uint256 _amount) public onlyOwner {
        IERC20(_tokenAddress).transfer(msg.sender, _amount);
    }

    function getVestingDataOwner(address _tokenAddress, address _address) public onlyOwner view returns (Vesting[] memory){
        return salesToken[_tokenAddress].addressToS[_address];
    }
}