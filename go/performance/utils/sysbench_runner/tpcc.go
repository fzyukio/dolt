package sysbench_runner

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

type tpccTesterImpl struct {
	test         Test
	config       Config
	serverConfig ServerConfig
	tpccCommand  string
	serverParams []string
	stampFunc    func() string
	idFunc       func() string
	suiteId      string
}

var _ Tester = &tpccTesterImpl{}

func NewTpccTester(config TpccConfig, serverConfig ServerConfig, test Test, serverParams []string, stampFunc func() string) *tpccTesterImpl {
	return &tpccTesterImpl{
		tpccCommand:  filepath.Join(config.GetScriptDir(), tpccLuaFilename),
		config:       config,
		serverParams: serverParams,
		serverConfig: serverConfig,
		test:         test,
		suiteId:      serverConfig.GetId(),
		stampFunc:    stampFunc,
	}
}

func (t *tpccTesterImpl) outputToResult(output []byte) (*Result, error) {
	return OutputToResult(output, t.serverConfig.GetServerType(), t.serverConfig.GetVersion(), t.test.GetName(), t.test.GetId(), t.suiteId, t.config.GetRuntimeOs(), t.config.GetRuntimeGoArch(), t.serverParams, t.test.GetParamsToSlice(), nil, false)
}

func (t *tpccTesterImpl) prepare(ctx context.Context) error {
	args := t.test.GetPrepareArgs(t.serverConfig)
	cmd := ExecCommand(ctx, t.tpccCommand, args...)
	cmd = t.updateCmdEnv(cmd)
	out, err := cmd.Output()
	if err != nil {
		fmt.Println(string(out))
		return err
	}
	return nil
}

func (t *tpccTesterImpl) run(ctx context.Context) (*Result, error) {
	args := t.test.GetRunArgs(t.serverConfig)
	cmd := ExecCommand(ctx, t.tpccCommand, args...)
	cmd = t.updateCmdEnv(cmd)

	out, err := cmd.Output()
	if err != nil {
		fmt.Print(string(out))
		return nil, err
	}

	if Debug == true {
		fmt.Print(string(out))
	}

	rs, err := t.outputToResult(out)
	if err != nil {
		return nil, err
	}

	rs.Stamp(t.stampFunc)

	return rs, nil
}

func (t *tpccTesterImpl) cleanup(ctx context.Context) error {
	args := t.test.GetCleanupArgs(t.serverConfig)
	cmd := ExecCommand(ctx, t.tpccCommand, args...)
	cmd = t.updateCmdEnv(cmd)
	err := cmd.Run()
	if err != nil {
		return err
	}
	return nil
}

func (t *tpccTesterImpl) Test(ctx context.Context) (*Result, error) {
	err := t.prepare(ctx)
	if err != nil {
		return nil, err
	}

	fmt.Println("Running test", t.test.GetName())

	rs, err := t.run(ctx)
	if err != nil {
		return nil, err
	}

	return rs, t.cleanup(ctx)
}

func (t *tpccTesterImpl) updateCmdEnv(cmd *exec.Cmd) *exec.Cmd {
	lp := filepath.Join(t.config.GetScriptDir(), luaPath)
	cmd.Env = os.Environ()
	cmd.Env = append(cmd.Env, fmt.Sprintf(luaPathEnvVarTemplate, lp))
	return cmd
}
