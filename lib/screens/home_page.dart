import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:task_tracker/models/announcement.dart';
import 'package:task_tracker/screens/announcement_screen.dart';
import 'package:task_tracker/screens/project_details_screen.dart';
import 'package:task_tracker/screens/tasks_list_screen.dart';
import 'package:task_tracker/services/announcement_operations.dart';
import 'package:task_tracker/services/employee_operations.dart';
import 'package:task_tracker/services/project_operations.dart';
import 'package:task_tracker/services/user_service.dart';

import '../models/employee.dart';
import '../models/project.dart';
import '../models/task_category.dart';
import '../models/task_role.dart';
import '../models/task_status.dart';
import '../services/task_categories.dart';
import '../services/task_provider.dart';
import '../task_screens/taskTitleScreen.dart';
import 'employee_details_screen.dart';
import 'employee_queue_screen.dart';

class HomeScreen extends StatefulWidget {
  static const routeName = '/homePage';

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final RxList<ProjectInformation> _projects = <ProjectInformation>[].obs;
  final RxList<Employee> _employees = <Employee>[].obs;
  final RxBool _isLoading = true.obs;
  final RxList<Announcement> _announcement = <Announcement>[].obs;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Ждем завершения инициализации пользователя
      if (!UserService.to.isInitialized.value) {
        await Future.doWhile(() async {
          await Future.delayed(const Duration(milliseconds: 100));
          return !UserService.to.isInitialized.value;
        });
      }

      // Проверяем авторизацию
      if (!UserService.to.isLoggedIn.value) {
        Get.offNamed(
            '/auth'); // Предполагается, что AuthScreen имеет routeName '/auth'
        return;
      }

      // Загружаем категории задач
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      await taskProvider.loadTasksAndCategories(
        taskCategories: TaskCategories(),
        position: 'Исполнитель',
        employeeId: UserService.to.currentUser!.userId,
      );

      // Загружаем проекты
      final List<ProjectInformation> projectsWithCounts = [];
      final currentUser = UserService.to.currentUser!;
      final projects =
          await EmployeeService().getAllProjects(currentUser.userId);

      for (final project in projects) {
        final workersCount =
            await ProjectService().getAllWorkersCount(project.projectId);
        projectsWithCounts.add(ProjectInformation(project, workersCount));
      }
      _projects.assignAll(projectsWithCounts);

      _announcement.assignAll(await AnnouncementService().getAnnouncements(currentUser.companyId));


      // Загружаем сотрудников
      final employees = await EmployeeService().getAllEmployees();
      _employees.assignAll(employees
          .where((e) => e.userId != UserService.to.currentUser!.userId));
    } catch (e) {
      _errorMessage = 'Ошибка загрузки данных: $e';
      Get.snackbar('Ошибка', _errorMessage!);
    } finally {
      _isLoading.value = false;
    }
  }

  Widget _buildShimmerSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _buildShimmerUserInfo(),
          const SizedBox(height: 20),
          _buildShimmerSearchBox(),
          const SizedBox(height: 20),
          _buildShimmerButton(),
          const SizedBox(height: 20),
          _buildShimmerAnnouncement(),
          const SizedBox(height: 20),
          _buildShimmerSection(title: 'Мои задачи', itemCount: 4),
          const SizedBox(height: 20),
          _buildShimmerSection(
              title: 'Сотрудники', itemCount: 3, isHorizontal: true),
          const SizedBox(height: 20),
          _buildShimmerSection(
              title: 'Проекты', itemCount: 2, isHorizontal: true),
        ],
      ),
    );
  }

  Widget _buildShimmerUserInfo() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 150, height: 20, color: Colors.white),
              const SizedBox(height: 4),
              Container(width: 100, height: 16, color: Colors.white),
            ],
          ),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerSearchBox() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildShimmerButton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildShimmerAnnouncement() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 100, height: 20, color: Colors.white),
            const SizedBox(height: 12),
            Container(height: 60, color: Colors.white),
            const SizedBox(height: 12),
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerSection(
      {required String title, int itemCount = 3, bool isHorizontal = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            width: 120,
            height: 24,
            color: Colors.white,
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: isHorizontal ? (title == 'Сотрудники' ? 180 : 140) : null,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            scrollDirection: isHorizontal ? Axis.horizontal : Axis.vertical,
            itemCount: itemCount,
            separatorBuilder: (context, index) => isHorizontal
                ? const SizedBox(width: 10)
                : const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Divider(),
                  ),
            itemBuilder: (context, index) {
              return isHorizontal
                  ? _buildShimmerHorizontalItem()
                  : _buildShimmerListItem();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerHorizontalItem() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(left: 16),
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 12),
            Container(width: 80, height: 12, color: Colors.white),
            const SizedBox(height: 6),
            Container(width: 60, height: 10, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerListItem() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 120, height: 16, color: Colors.white),
                  const SizedBox(height: 4),
                  Container(width: 80, height: 14, color: Colors.white),
                ],
              ),
            ),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!UserService.to.isInitialized.value || _isLoading.value) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: _buildShimmerSkeleton(),
        );
      }

      if (!UserService.to.isLoggedIn.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.offNamed('/auth');
        });
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      return Scaffold(
        backgroundColor: Colors.white,
        body: _errorMessage != null
            ? Center(child: Text(_errorMessage!))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildUserInfo(),
                    const SizedBox(height: 20),
                    _buildSearchBox(),
                    const SizedBox(height: 20),
                    _buildAddTaskButton(),
                    const SizedBox(height: 20),
                    if(UserService.to.currentUser!.role == 'Директор')...[
                      _buildAddAnnouncementButton(),
                      const SizedBox(height: 20),
                    ],
                    if(_announcement.isNotEmpty) ...[
                      _buildAnnouncementCard(),
                      const SizedBox(height: 20),
                    ],
                    _buildTasksSection(),
                    const SizedBox(height: 20),
                    _buildEmployeesSection(),
                    const SizedBox(height: 20),
                    _buildProjectsSection(),
                  ],
                ),
              ),
      );
    });
  }

  Widget _buildUserInfo() {
    final user = UserService.to.currentUser!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.name.split(' ').take(2).join(' '),
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.normal),
            ),
            Text(
              user.position,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
        // IconButton(
        //   icon: Stack(
        //     children: [
        //       const Icon(Icons.notifications),
        //       Positioned(
        //         right: 0,
        //         top: 0,
        //         child: Container(
        //           padding: const EdgeInsets.all(2),
        //           decoration: BoxDecoration(
        //             color: Colors.red,
        //             borderRadius: BorderRadius.circular(10),
        //           ),
        //           constraints: const BoxConstraints(
        //             minWidth: 16,
        //             minHeight: 16,
        //           ),
        //           child: const Text(
        //             '3', // TODO: Замените на реальное количество уведомлений
        //             style: TextStyle(
        //               color: Colors.white,
        //               fontSize: 10,
        //             ),
        //             textAlign: TextAlign.center,
        //           ),
        //         ),
        //       ),
        //     ],
        //   ),
        //   onPressed: () {
        //     // TODO: Реализуйте переход на экран уведомлений
        //     // Get.toNamed('/notifications');
        //   },
        // ),
      ],
    );
  }

  Widget _buildSearchBox() {
    return TextField(
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey[200],
        prefixIcon: const Icon(Icons.search, color: Colors.grey),
        hintText: 'Поиск',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
      onChanged: (value) {
        // TODO: Реализуйте логику поиска
      },
    );
  }

  Widget _buildAddTaskButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Get.toNamed(TaskTitleScreen.routeName);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 4,
          shadowColor: Colors.blue.withOpacity(0.3),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 20),
            SizedBox(width: 8),
            Text(
              'Поставить задачу',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddAnnouncementButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Get.toNamed('/create_announcement');
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Colors.orange,width: 1),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 4,
          shadowColor: Colors.blue.withOpacity(0.3),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 20),
            SizedBox(width: 8),
            Text(
              'Написать объявление',
              style: TextStyle(fontSize: 16, color: Colors.black, fontFamily: 'Roboto'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard() {
    final announcement = _announcement.last; // Берем последнее объявление
    final userRole = UserService.to.currentUser!.role;
    final showReadCount = userRole == 'Директор' || userRole == 'Коммуникатор';

    return GestureDetector(
      onTap: () {
        Get.toNamed('/announcement_detail', arguments: announcement);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Iconsax.flash, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    'ОБЪЯВЛЕНИЕ',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 14, color: Colors.red
                    ),
                  ),
                ],
              ),
              Text(
                announcement.title,
                style: Theme.of(context).textTheme.bodyMedium
              ),
              const SizedBox(height: 16),
              Text(
                'Cтатус объявления',
                style: Theme.of(context).textTheme.titleSmall
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Iconsax.eye, size: 18, color: Colors.black),
                        const SizedBox(width: 8),
                        Text(
                          'Прочитали ' + announcement.readBy.length.toString(),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => AnnouncementDetailScreen(announcement: announcement,),
                    ));
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Colors.orange, width: 1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 24),
                  ),
                  child: Text(
                     UserService.to.currentUser!.role=='Директор'?'Посмотреть':'Прочитать',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.normal),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTasksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Мои задачи',
            style: TextStyle(
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8.0),
        Consumer<TaskProvider>(
          builder: (context, taskProvider, child) {
            final categories = taskProvider.getCategories(
              RoleHelper.convertToString(TaskRole.executor),
              UserService.to.currentUser!.userId,
            );

            if (categories.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(1.0),
              itemCount: categories.length,
              separatorBuilder: (context, index) => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Divider(),
              ),
              itemBuilder: (context, index) {
                final category = categories[index];
                return _buildTaskCategoryItem(category);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildTaskCategoryItem(TaskCategory category) {
    final icon = StatusHelper.getStatusIcon(
        category.status); // Используем существующий метод

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      leading: Icon(icon, color: Colors.blue),
      title: Text(
        category.title,
        style: const TextStyle(fontSize: 16.0),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Text(
          category.count.toString(),
          style: const TextStyle(
            fontSize: 14.0,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      onTap: () => _handleCategoryTap(category),
    );
  }

  void _handleCategoryTap(TaskCategory category) async {
    try {
      if (category.status == TaskStatus.queue) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QueueScreen(
              position: RoleHelper.convertToString(TaskRole.executor),
              userId: UserService.to.currentUser!.userId,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TaskListByStatusScreen(
              position: RoleHelper.convertToString(TaskRole.executor),
              userId: UserService.to.currentUser!.userId,
              status: category.status,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки задач: ${e.toString()}')),
      );
    }
  }

  Widget _buildEmployeesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Сотрудники',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _employees.length.toString(),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _employees.isEmpty
            ? const Center(child: Text('Нет сотрудников'))
            : SizedBox(
                height: 180,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _employees.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 10),
                  itemBuilder: (context, index) =>
                      _buildEmployeeCell(_employees[index]),
                ),
              ),
      ],
    );
  }

  Widget _buildEmployeeCell(Employee employee) {
    return GestureDetector(
      onTap: () {
        Get.to(() => EmployeeDetailScreen(employee: employee));
      },
      child: SizedBox(
        width: 120,
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              SizedBox(
                height: 68,
                child: CircleAvatar(
                  radius: 34,
                  backgroundImage: (employee.avatarUrl != null &&
                          employee.avatarUrl!.isNotEmpty)
                      ? NetworkImage(
                          ProjectService().getAvatarUrl(employee.avatarUrl!) ??
                              '')
                      : null,
                  child: (employee.avatarUrl == null ||
                          employee.avatarUrl!.isEmpty)
                      ? const Icon(Icons.account_box, size: 34)
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 32,
                child: Text(
                  employee.name.split(' ').take(2).join(' '),
                  style: const TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 20,
                child: Text(
                  employee.position,
                  style: const TextStyle(fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Проекты',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _projects.length.toString(),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _projects.isEmpty
            ? const Center(child: Text('Нет проектов'))
            : SizedBox(
                height: 140,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _projects.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 10),
                  itemBuilder: (context, index) =>
                      _buildProjectCell(_projects[index]),
                ),
              ),
      ],
    );
  }

  Widget _buildProjectCell(ProjectInformation project) {
    return GestureDetector(
      onTap: () {
        Get.to(() => ProjectDetailsScreen(project: project.project));
      },
      child: SizedBox(
        width: 150,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              CircleAvatar(
                radius: 17,
                backgroundImage: (project.project.avatarUrl != null &&
                        project.project.avatarUrl!.isNotEmpty)
                    ? NetworkImage(ProjectService()
                            .getAvatarUrl(project.project.avatarUrl!) ??
                        '')
                    : null,
                child: (project.project.avatarUrl == null ||
                        project.project.avatarUrl!.isEmpty)
                    ? const Icon(Icons.account_box, size: 17)
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                project.project.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.account_circle_sharp, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    project.employees.toString(),
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProjectInformation {
  final Project project;
  final int employees;

  ProjectInformation(this.project, this.employees);
}
