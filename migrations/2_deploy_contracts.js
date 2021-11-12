const TreasuryVester = artifacts.require("TreasuryVester");
const LiquidityPoolManager = artifacts.require("LiquidityPoolManager");
const BoostedLiquidityPoolManager = artifacts.require("BoostedLiquidityPoolManager");

const PARTY = '0xCEAA8d36a189b3d8b867AD534D91A3Bdbd31686b'; //FUJI-v2
// const PARTY = '0x25afD99fcB474D7C336A2971F26966da652a92bc'; //MAINNET-v2

// const WAVAX = '0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7'; //MAINNET
const WAVAX = '0xd00ae08403B9bbb9124bB305C09058E32C39A48c'; //FUJI

const STABLETOKEN = '0x2058ec2791dD28b6f67DB836ddf87534F4Bbdf22'; //FUJISTABLE ADDRESS
// const STABLETOKEN = '0xc7198437980c041c805A1EDcbA50c1Ce5db95118'; //USDT.e


// Just use this if deploying entire solution
// module.exports = function (deployer) {
//   deployer.deploy(TreasuryVester, PARTY).then(
//     () => {
//       return deployer.deploy(BoostedLiquidityPoolManager, WAVAX, PARTY, STABLETOKEN, TreasuryVester.address)
//     }
//   );
// };

// Just use this when deploying a new vester
// module.exports = function (deployer) {
//   deployer.deploy(TreasuryVester, PARTY);
// };

// Just use this if deploying an LPM with an existing Vester
const TREASURY_VESTER_ADDRESS = '0x28Cf21Fc82525146E6A2dE1459e673dAF493F88f'; //FUJI
// const TREASURY_VESTER_ADDRESS = '0x3af549E2a3de76b15399FaADef6Fe118c62f8dB5'; //MAINNET

module.exports = function (deployer) {
  deployer.deploy(BoostedLiquidityPoolManager, WAVAX, PARTY, STABLETOKEN, TREASURY_VESTER_ADDRESS)
};