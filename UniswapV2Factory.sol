pragma solidity =0.5.16;

import './interfaces/IUniswapV2Factory.sol';
import './UniswapV2Pair.sol';

contract UniswapV2Factory is IUniswapV2Factory {
    address public feeTo;
    address public feeToSetter;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'UniswapV2: PAIR_EXISTS'); // single check is sufficient
        // type(x).creationCode 获得包含x的合约的bytecode,是bytes类型(不能在合同本身或继承的合约中使用,因为会引起循环引用)
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            /**
             * @dev: create2方法 - 在已知bytecode及salt的情况下返回新的交易对地址(针对此算法可以提前知道交易对的地址)
             * @notice create2(V, P, N, S) - V: 发送V数量wei以太,P: 起始内存地址,N: bytecode长度,S: salt
             * @param {uint} 指创建合约后向合约发送x数量wei的以太币
             * @param {bytes} add(bytecode, 32) opcode的add方法,将bytecode偏移后32位字节处,因为前32位字节存的是bytecode长度
             * @param {bytes} mload(bytecode) opcode的方法,获得bytecode长度
             * @param {bytes} salt 盐值
             * @return {address} 返回新的交易对地址
             */
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        // 将新的交易对地址初始化到pair合约中(因为create2函数创建合约时无法提供构造函数参数)
        IUniswapV2Pair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    /**  
     * @dev: 设置团队手续费开关
     * @notice 在uniswapV2中,用户交易代币时,会被收取交易额的千分之三手续费分配给所有流动性提供者.
     * @param {address} 不为零地址,则代表开启手续费开关(手续费中的1/6分给此地址),为零地址则代表关闭手续费开关
     */
    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
}
