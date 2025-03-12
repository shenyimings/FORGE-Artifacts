// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./interfaces/IMaLPNFT.sol";
import "./interfaces/IMaGauge.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IVoterV3.sol";
import "./interfaces/IMaGaugeV2.sol";

// The base pair of pools, either stable or volatile
contract MigrateMaNFT {

    IMaLPNFT public maNFT;
    IVoterV3 public voterV3;
    IVoterV3 public oldVoter;

    uint public constant WEEK = 24*60*60*7;
    uint public constant maturityIncrement = 3628800;
    uint public constant MATURITY_PRECISION = 1e18;

    constructor( address _maNFT, address _voterV3, address _oldVoter) {
        maNFT = IMaLPNFT(_maNFT);
        voterV3 = IVoterV3(_voterV3);
        oldVoter = IVoterV3(_oldVoter);

    }

    function migrate(uint[] memory _tokenIds) external {

        uint len = _tokenIds.length;

        for ( uint i ; i<len; i++) {
            uint _tokenId = _tokenIds[i];
            address _oldGaugeAddress = maNFT.tokenToGauge(_tokenId);
            address _owner = maNFT.ownerOf(_tokenId);
            

            IMaGauge _oldGauge = IMaGauge(_oldGaugeAddress);

            address pairOfGauge = oldVoter.poolForGauge(_oldGaugeAddress);

            uint maturity = _oldGauge.maturityLevelOfTokenMaxBoost(_tokenId);
            uint _lpAmountBefore = IERC20(pairOfGauge).balanceOf(address(this));

            _oldGauge.withdrawAndHarvest(_tokenId);


            uint _lpAmountAfter = IERC20(pairOfGauge).balanceOf(address(this));


            uint _lpAmount = _lpAmountAfter - _lpAmountBefore;

            

            address _newGauge = voterV3.gauges(pairOfGauge);

            IERC20(pairOfGauge).approve(_newGauge,_lpAmount);

            uint entry = block.timestamp - maturity * WEEK;

            IMaGaugeV2(_newGauge).depositFromMigration(_lpAmount, _owner, entry);

            
        }
    }
    
}
