//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IKaiDexFactory.sol";
import "./interfaces/IKRC20.sol";

interface IPair is IERC20 {
    function token0() external view returns (IERC20);

    function token1() external view returns (IERC20);

    function getReserves()
        external
        view
        returns (
            uint112,
            uint112,
            uint32
        );
}

contract BoringHelper {
    struct TokenInfo {
        IKRC20 token;
        uint256 decimals;
        string name;
        string symbol;
    }

    struct PairBase {
        IPair token;
        IERC20 token0;
        IERC20 token1;
        uint256 totalSupply;
    }

    struct PairPoll {
        IPair token;
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalSupply;
        uint256 balance;
    }

    function getTokenInfo(address[] calldata addresses)
        public
        view
        returns (TokenInfo[] memory)
    {
        TokenInfo[] memory infos = new TokenInfo[](addresses.length);
        for (uint256 i = 0; i < addresses.length; i++) {
            IKRC20 token = IKRC20(addresses[i]);
            infos[i].token = token;
            infos[i].name = token.name();
            infos[i].symbol = token.symbol();
            infos[i].decimals = token.decimals();
        }
        return infos;
    }

    function getPairs(
        IKaiDexFactory factory,
        uint256 fromID,
        uint256 toID
    ) public view returns (PairBase[] memory) {
        PairBase[] memory pairs = new PairBase[](toID - fromID);

        for (uint256 id = fromID; id < toID; id++) {
            IPair token = IPair(factory.allPairs(id));
            uint256 i = id - fromID;
            pairs[i].token = token;
            pairs[i].token0 = token.token0();
            pairs[i].token1 = token.token1();
            pairs[i].totalSupply = token.totalSupply();
        }
        return pairs;
    }

    function pollPairs(address who, IPair[] calldata addresses)
        public
        view
        returns (PairPoll[] memory)
    {
        PairPoll[] memory pairs = new PairPoll[](addresses.length);
        for (uint256 i = 0; i < addresses.length; i++) {
            IPair token = addresses[i];
            pairs[i].token = token;
            (uint256 reserve0, uint256 reserve1, ) = token.getReserves();
            pairs[i].reserve0 = reserve0;
            pairs[i].reserve1 = reserve1;
            pairs[i].balance = token.balanceOf(who);
            pairs[i].totalSupply = token.totalSupply();
        }
        return pairs;
    }
}
