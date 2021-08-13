const TreasuryVester = artifacts.require("TreasuryVester");
const LiquidityPoolManager = artifacts.require("LiquidityPoolManager");
const YAY = '0x15957be9802B50c6D66f58a99A2a3d73F5aaf615';

module.exports = function (deployer) {
  deployer.deploy(TreasuryVester, YAY).then(
    () => {
      const WAVAX = '0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7';
      return deployer.deploy(LiquidityPoolManager, WAVAX, YAY, TreasuryVester.address)
    }
  );
};
