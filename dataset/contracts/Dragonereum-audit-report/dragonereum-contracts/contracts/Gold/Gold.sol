pragma solidity 0.4.25;

import "./ERC20.sol";
import "../Common/Upgradable.sol";

contract Gold is ERC20, Upgradable {
    uint256 constant DEVS_STAKE = 6; // 1/6

    address[5] founders = [
        0x23b3763f31F4da6B42F47927BCF66A221E8705Cd,
        0x5CFF40372b96e133967d980F72812653163121fa,
        0xE246C5Aa2D57878DA70779A75B12dCDFFd77aDBA,
        0x950eEAf8ddbA1409dbD25aD16d50A867EEA75c3E,
        0x87252E8F04F6c6bC4d2c690893addb7108aa8a5f
    ];

    address foundation = 0x5Ff8957EF7e964E8072815211c9Fc3E7F820F1D4;
    address NonsenseGames = 0x10208FB4Ef202BdC49803995b0A8CA185383bba4;

    string constant WP_IPFS_HASH = "QmfR75tK12q2LpkU5dzYqykUUpYswSiewpCbDuwYhRb6M5";


    constructor(address treasury) public {
        name = "Dragonereum Gold";
        symbol = "GOLD";
        decimals = 18;

        uint256 _foundersGold = 6000000 * 10**18; // 10%
        uint256 _foundationGold = 6000000 * 10**18; // 10%
        uint256 _NonsenseGamesGold = 3000000 * 10**18; // 5%
        uint256 _gameAccountGold = 45000000 * 10**18; // 75%

        uint256 _founderStake = _foundersGold.div(founders.length);
        for (uint256 i = 0; i < founders.length; i++) {
            _mint(founders[i], _founderStake);
        }

        _mint(foundation, _foundationGold);
        _mint(NonsenseGames, _NonsenseGamesGold);
        _mint(treasury, _gameAccountGold);

        require(_totalSupply == 60000000 * 10**18, "wrong total supply");
    }

    function remoteTransfer(address _to, uint256 _value) external onlyController {
        _transfer(tx.origin, _to, _value); // solium-disable-line security/no-tx-origin
    }

    function burn(uint256 _value) external onlyController {
        _burn(msg.sender, _value);
    }
}
