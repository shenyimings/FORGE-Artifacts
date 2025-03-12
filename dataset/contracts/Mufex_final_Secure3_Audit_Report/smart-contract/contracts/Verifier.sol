
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./Ownable.sol";
import "./interfaces/IMainTreasury.sol";
import "./libraries/Pairing.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract Verifier is Ownable, Initializable {
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    using Pairing for *;

    uint256 constant SNARK_SCALAR_FIELD = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    uint256 constant PRIME_Q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    address public operator;
    address public mainTreasury;
    address public usdt;

    struct VerifyingKey {
        Pairing.G1Point alfa1;
        Pairing.G2Point beta2;
        Pairing.G2Point gamma2;
        Pairing.G2Point delta2;
        Pairing.G1Point[2] IC;
    }

    struct Proof {
        Pairing.G1Point A;
        Pairing.G2Point B;
        Pairing.G1Point C;
    }

    function initialize(
        address operator_,
        address mainTreasury_, 
        address usdt_
    ) external initializer {
        owner = msg.sender;
        operator = operator_;
        mainTreasury = mainTreasury_;
        usdt = usdt_;
    }

    function updateOperator(address newOperator) external onlyOwner {
        require(newOperator != address(0), "zero address");
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    /*
     * 电路修改后，vk需要同步更新（@kg需要改成可更新的）
     */
    function verifyingKey() internal pure returns (VerifyingKey memory vk) {
        vk.alfa1 = Pairing.G1Point(uint256(5405201782098463060161137549655070471981737101111284299770432932868146686249), uint256(5981703316555082043701193338233703339548963638124510305244518862511571337772));
        vk.beta2 = Pairing.G2Point([uint256(19771466197315070773439446976073379003904842313011769668524550257273504697198), uint256(6673448270177140253544369469582247615353980242675976829425282403112596564529)], [uint256(10045469853770426668693425387553546132727425490278638514344172051195044651652), uint256(7171443872375773199195938653017137711884025769637746927801436782689507288954)]);
        vk.gamma2 = Pairing.G2Point([uint256(15227563440121859371734634844026058619047607578723137004425803131022778781820), uint256(18705218464923437842377968636110739043675259460794947161300156093217409356773)], [uint256(20216510798328125783060394427831229300146725991339908301421546377090798395827), uint256(16975499785940743132417229998991630996523412614442308525942357861109233143069)]);
        vk.delta2 = Pairing.G2Point([uint256(3589279472710563910522175723201776252463657035811655684708578792277219406563), uint256(17392178979474284103716623029717194908562826516880174834787687816816938951383)], [uint256(16579297284444354302696508268930780714226916923937594952343276941132770414435), uint256(3592966907124190431988140232017226412453190021470172996254146861890812470476)]);   
        vk.IC[0] = Pairing.G1Point(uint256(10672263234464850849385702831686315516154676600092869209435072635381075523513), uint256(10571226288176792501316533571159631987471316998895346816415236632185902750504));   
        vk.IC[1] = Pairing.G1Point(uint256(18677888034723623894892132431604846029463446484302557187614276140041565620491), uint256(10761786999442075491040771539463948587214768621155456662279033036606204822041));
    }
    
    /*
     * @returns Whether the proof is valid given the hardcoded verifying key
     *          above and the public inputs
     */
    function verifyProof(
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[4] memory input
    ) public view returns (bool r) {

        Proof memory proof;
        proof.A = Pairing.G1Point(a[0], a[1]);
        proof.B = Pairing.G2Point([b[0][0], b[0][1]], [b[1][0], b[1][1]]);
        proof.C = Pairing.G1Point(c[0], c[1]);

        VerifyingKey memory vk = verifyingKey();

        // Compute the linear combination vk_x
        Pairing.G1Point memory vk_x = Pairing.G1Point(0, 0);

        // Make sure that proof.A, B, and C are each less than the prime q
        require(proof.A.X < PRIME_Q, "verifier-aX-gte-prime-q");
        require(proof.A.Y < PRIME_Q, "verifier-aY-gte-prime-q");

        require(proof.B.X[0] < PRIME_Q, "verifier-bX0-gte-prime-q");
        require(proof.B.Y[0] < PRIME_Q, "verifier-bY0-gte-prime-q");

        require(proof.B.X[1] < PRIME_Q, "verifier-bX1-gte-prime-q");
        require(proof.B.Y[1] < PRIME_Q, "verifier-bY1-gte-prime-q");

        require(proof.C.X < PRIME_Q, "verifier-cX-gte-prime-q");
        require(proof.C.Y < PRIME_Q, "verifier-cY-gte-prime-q");

        // Make sure that every input is less than the snark scalar field
        for (uint256 i = 0; i < input.length; i++) {
            require(input[i] < SNARK_SCALAR_FIELD,"verifier-gte-snark-scalar-field");
            vk_x = Pairing.plus(vk_x, Pairing.scalar_mul(vk.IC[i + 1], input[i]));
        }

        vk_x = Pairing.plus(vk_x, vk.IC[0]);

        return Pairing.pairing(
            Pairing.negate(proof.A),
            proof.B,
            vk.alfa1,
            vk.beta2,
            vk_x,
            vk.gamma2,
            proof.C,
            vk.delta2
        );
    }

    function submit(
        uint64 zkpId,
        uint256[] memory BeforeAccountTreeRoot,
        uint256[] memory AfterAccountTreeRoot,
        uint256[] memory BeforeCEXAssetsCommitment,
        uint256[] memory AfterCEXAssetsCommitment,
        uint256[2][] memory a, // zk proof参数
        uint256[2][2][] memory b, // zk proof参数
        uint256[2][] memory c, // zk proof参数
        uint256 withdrawMerkelTreeToot,
        uint256 totalBalance,
        uint256 totalWithdraw
    ) public returns (bool r) {
        require(msg.sender == operator, "only operator");
        // 确保输入数组的长度匹配
        require(BeforeAccountTreeRoot.length == AfterAccountTreeRoot.length,"BeforeAccountTreeRoot.length != AfterAccountTreeRoot.length");
        require(BeforeAccountTreeRoot.length == BeforeCEXAssetsCommitment.length,"BeforeAccountTreeRoot.length != BeforeCEXAssetsCommitment.length");
        require(BeforeAccountTreeRoot.length == AfterCEXAssetsCommitment.length,"BeforeAccountTreeRoot.length != AfterCEXAssetsCommitment.length");
        require(BeforeAccountTreeRoot.length == a.length,"BeforeAccountTreeRoot.length != a.length");
        require(BeforeAccountTreeRoot.length == b.length,"BeforeAccountTreeRoot.length != b.length");
        require(BeforeAccountTreeRoot.length == c.length,"BeforeAccountTreeRoot.length != c.length");

        // 确保前一个数据的after值为后一个数据的before值
        for (uint256 i = 1; i < BeforeAccountTreeRoot.length; i++) {
            require(BeforeAccountTreeRoot[i] == AfterAccountTreeRoot[i-1],"BeforeAccountTreeRoot[i] != AfterAccountTreeRoot[i-1]");
            require(BeforeCEXAssetsCommitment[i] == AfterCEXAssetsCommitment[i-1],"BeforeCEXAssetsCommitment[i] != AfterCEXAssetsCommitment[i-1]");
        }

        // 确保zk proof是准确的
        for (uint256 i = 0; i < BeforeAccountTreeRoot.length; i++) {
            uint256[4] memory input = [
                    BeforeAccountTreeRoot[i],
                    AfterAccountTreeRoot[i],
                    BeforeCEXAssetsCommitment[i],
                    AfterCEXAssetsCommitment[i]
                ];
            bool rst = verifyProof(
                a[i],
                b[i],
                c[i],
                input
            );
            require(rst,"zk proof fail");
        }

        _updateZKP(zkpId, AfterAccountTreeRoot[AfterAccountTreeRoot.length - 1], withdrawMerkelTreeToot, totalBalance, totalWithdraw);
        return true;
    }

    function _updateZKP(
        uint64 zkpId,
        uint256 balanceMerkelTreeToot,
        uint256 withdrawMerkelTreeToot,
        uint256 totalBalance,
        uint256 totalWithdraw
    ) internal {
        address[] memory tokens = new address[](1);
        tokens[0] = usdt;
        uint256[] memory newBalanceRoots = new uint256[](1);
        newBalanceRoots[0] = balanceMerkelTreeToot;
        uint256[] memory newWithdrawRoots = new uint256[](1);
        newWithdrawRoots[0] = withdrawMerkelTreeToot;
        uint256[] memory newTotalBalances = new uint256[](1);
        newTotalBalances[0] = totalBalance;
        uint256[] memory newTotalWithdraws = new uint256[](1);
        newTotalWithdraws[0] = totalWithdraw;
        IMainTreasury(mainTreasury).updateZKP(zkpId, tokens, newBalanceRoots, newWithdrawRoots, newTotalBalances, newTotalWithdraws);
    }
}
