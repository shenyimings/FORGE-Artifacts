// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../libraries/Position.sol";

contract PositionMock {
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;

    mapping(bytes32 => Position.Info) public positions;

    /*///////////////////////////////////////////////////////////////
                        POSITIONS MAPPING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function get(address owner, uint256 id) external view returns (Position.Info memory) {
        Position.Info memory position = positions.get(owner, id);
        return position;
    }

    function set(
        address owner,
        uint256 id,
        Position.Info memory pos
    ) external {
        positions.set(owner, id, pos);
    }

    /*///////////////////////////////////////////////////////////////
                    POSITION GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function exists(Position.Info memory pos) external view returns (bool) {
        return pos.exists();
    }

    /*///////////////////////////////////////////////////////////////
                        POSITION CALC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function notionalInitial(Position.Info memory pos, uint256 fraction)
        external
        view
        returns (uint256)
    {
        return pos.notionalInitial(fraction);
    }

    function oiInitial(Position.Info memory pos, uint256 fraction)
        external
        view
        returns (uint256)
    {
        return pos.oiInitial(fraction);
    }

    function oiSharesCurrent(Position.Info memory pos, uint256 fraction)
        external
        view
        returns (uint256)
    {
        return pos.oiSharesCurrent(fraction);
    }

    function oiCurrent(
        Position.Info memory pos,
        uint256 fraction,
        uint256 oiTotalOnSide,
        uint256 oiTotalSharesOnSide
    ) external view returns (uint256) {
        return pos.oiCurrent(fraction, oiTotalOnSide, oiTotalSharesOnSide);
    }

    function debtCurrent(Position.Info memory pos, uint256 fraction)
        external
        view
        returns (uint256)
    {
        return pos.debtCurrent(fraction);
    }

    function cost(Position.Info memory pos, uint256 fraction) external view returns (uint256) {
        return pos.cost(fraction);
    }

    function value(
        Position.Info memory pos,
        uint256 fraction,
        uint256 oiTotalOnSide,
        uint256 oiTotalSharesOnSide,
        uint256 currentPrice,
        uint256 capPayoff
    ) external view returns (uint256) {
        return pos.value(fraction, oiTotalOnSide, oiTotalSharesOnSide, currentPrice, capPayoff);
    }

    function notionalWithPnl(
        Position.Info memory pos,
        uint256 fraction,
        uint256 oiTotalOnSide,
        uint256 oiTotalSharesOnSide,
        uint256 currentPrice,
        uint256 capPayoff
    ) external view returns (uint256) {
        return
            pos.notionalWithPnl(
                fraction,
                oiTotalOnSide,
                oiTotalSharesOnSide,
                currentPrice,
                capPayoff
            );
    }

    function tradingFee(
        Position.Info memory pos,
        uint256 fraction,
        uint256 oiTotalOnSide,
        uint256 oiTotalSharesOnSide,
        uint256 currentPrice,
        uint256 capPayoff,
        uint256 tradingFeeRate
    ) external view returns (uint256) {
        return
            pos.tradingFee(
                fraction,
                oiTotalOnSide,
                oiTotalSharesOnSide,
                currentPrice,
                capPayoff,
                tradingFeeRate
            );
    }

    function liquidatable(
        Position.Info memory pos,
        uint256 oiTotalOnSide,
        uint256 oiTotalSharesOnSide,
        uint256 currentPrice,
        uint256 capPayoff,
        uint256 maintenanceMarginFraction
    ) external view returns (bool) {
        return
            pos.liquidatable(
                oiTotalOnSide,
                oiTotalSharesOnSide,
                currentPrice,
                capPayoff,
                maintenanceMarginFraction
            );
    }

    function liquidationPrice(
        Position.Info memory pos,
        uint256 oiTotalOnSide,
        uint256 oiTotalSharesOnSide,
        uint256 maintenanceMarginFraction
    ) external view returns (uint256) {
        return pos.liquidationPrice(oiTotalOnSide, oiTotalSharesOnSide, maintenanceMarginFraction);
    }
}
