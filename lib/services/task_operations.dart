import 'dart:developer';
import 'dart:io';

import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task_tracker/services/task_categories.dart';
import 'package:uuid/uuid.dart';

import '../models/employee.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../models/task_status.dart';

class TaskService {
  late SupabaseClient _client = Supabase.instance.client;

  TaskService();

  TaskService.forTest(this._client);

  Future<Task> getTask(String taskId) async {
    try {
      final response = await _client.from('task').select('''
  *,
      project:project_id(*,
        project_description_id:project_description_id(*),
        project_observers:project_observers(
          *,
          employee:employee_id(*)
        )
      ),
      task_team: task_team!task_team_task_id_fkey(*,
        creator_id:creator_id(*),
        communicator_id:communicator_id(*),
        observer_id:observer_id(*),
        team_members:team_id(*,
          employee_id:employee_id(*)
        )
      )
''').eq('id', taskId).single();

      return Task.fromJson(response);
    } catch (e) {
      print('Ошибка при загрузке задачи: ${e}');
      rethrow;
    }
  }

  Future<Map<String, int>> getCountOfTasksByStatus(
      String position, String employeeId) async {
    try {
      late List<dynamic> tasksResponse;

      if (position == 'Исполнитель') {
        // Логика для исполнителя
        final teamsResponse = await _client
            .from('team_members')
            .select('team_id')
            .eq('employee_id', employeeId);

        if (teamsResponse.isEmpty) return _initializeEmptyStatusMap();

        final teamIds = (teamsResponse as List)
            .map((team) => team['team_id'] as String)
            .toList();

        tasksResponse = await _client
            .from('task_team')
            .select('task:task_id(status)')
            .inFilter('team_id', teamIds);
      } else if (position == 'Постановщик') {
        tasksResponse = await _client
            .from('task_team')
            .select('task:task_id(status)')
            .eq('creator_id', employeeId);

        if (tasksResponse.isEmpty) return _initializeEmptyStatusMap();
      } else if (position == 'Коммуникатор') {
        tasksResponse = await _client
            .from('task_team')
            .select('task:task_id(status)')
            .eq('communicator_id', employeeId);

        if (tasksResponse.isEmpty) return _initializeEmptyStatusMap();
      } else if (position == 'Наблюдатель') {
        tasksResponse = await _client
            .from('task_team')
            .select('task:task_id(status)')
            .eq('observer_id', employeeId);

        if (tasksResponse.isEmpty) return _initializeEmptyStatusMap();
      }

      // Общая логика обработки задач
      final statusCounts = _initializeEmptyStatusMap();

      for (final task in tasksResponse) {
        if (task != null) {
          final status = task['status'] ?? task['task']['status'];

          final taskStatus = StatusHelper.toTaskStatus(status);
          statusCounts[StatusHelper.displayName(taskStatus)] =
              (statusCounts[StatusHelper.displayName(taskStatus)] ?? 0) + 1;
        }
      }

      return statusCounts;
    } on PostgrestException catch (error) {
      print('Ошибка при получении количества задач: ${error.message}');
      return _initializeEmptyStatusMap();
    } catch (e) {
      print('Неожиданная ошибка: $e');
      return _initializeEmptyStatusMap();
    }
  }

  Map<String, int> _initializeEmptyStatusMap() {
    return {
      for (var status in TaskStatus.values) StatusHelper.displayName(status): 0
    };
  }

  Future<List<Task>> getProjectTasksByStatus({required String projectId}) async {
    try {
      final tasksResponse = await _client.from('task').select('''
      *,
      project:project_id(*,
        project_description_id:project_description_id(*),
        project_team:project_team(
        *,
        employee:employee_id(*)
      )
      ),
      task_team: task_team!task_team_task_id_fkey(*,
        creator_id:creator_id(*),
        communicator_id:communicator_id(*),
        observer_id:observer_id(*),
        team_members:team_id(*,
          employee_id:employee_id(*)
        )
      )
    ''').eq('project_id', projectId);

      if (tasksResponse.isEmpty) return [];

      return tasksResponse.map((taskData) => Task.fromJson(taskData)).toList();
    } catch (e) {
      print('Error getting project tasks by status: $e');
      return [];
    }
  }

  Future<List<Task>> getTasksByStatus({required String position, required TaskStatus status, required String employeeId,}) async {
    try {
      final statusString = status.toString().substring(11);

      if (position == 'Коммуникатор') {
        final taskIdsResponse = await _client
            .from('task_team')
            .select('task_id')
            .eq('communicator_id', employeeId);

        if (taskIdsResponse.isEmpty) return [];

        final taskIds =
            taskIdsResponse.map((item) => item['task_id'] as String).toList();

        // 2. Получаем полные данные задач с фильтрацией по статусу
        final tasksResponse = await _client.from('task').select('''
      *,
      project:project_id(*,
        project_description_id:project_description_id(*),
        project_team:project_team:project_id(
        *,
        employee:employee_id(*)
      )
      ),
      task_team: task_team!task_team_task_id_fkey(*,
        creator_id:creator_id(*),
        communicator_id:communicator_id(*),
        observer_id:observer_id(*),
        team_members:team_id(*,
          employee_id:employee_id(*)
        )
      )
    ''').inFilter('id', taskIds).eq('status', statusString);

        return tasksResponse
            .map((taskData) => Task.fromJson(taskData))
            .toList();
      } else if (position == 'Постановщик') {
        // 1. Получаем список ID задач с нужным статусом и creator_id
        final taskIdsResponse = await _client
            .from('task_team')
            .select('task_id')
            .eq('creator_id', employeeId);

        if (taskIdsResponse.isEmpty) return [];

        final taskIds =
            taskIdsResponse.map((item) => item['task_id'] as String).toList();

        final tasksResponse = await _client.from('task').select('''
      *,
      project:project_id(*,
        project_description_id:project_description_id(*),
        project_team:project_team:project_id(
        *,
        employee:employee_id(*)
      )
      ),
      task_team: task_team!task_team_task_id_fkey(*,
        creator_id:creator_id(*),
        communicator_id:communicator_id(*),
        observer_id:observer_id(*),
        team_members:team_id(*,
          employee_id:employee_id(*)
        )
      )
    ''').inFilter('id', taskIds).eq('status', statusString);

        return tasksResponse
            .map((taskData) => Task.fromJson(taskData))
            .toList();
      } else if (position == 'Исполнитель') {
        // Для исполнителя получаем задачи через team_members
        final teamsResponse = await _client
            .from('team_members')
            .select('task_team:team_id(task_id)')
            .eq('employee_id', employeeId);

        if (teamsResponse.isEmpty) return [];

        final taskIds = (teamsResponse as List)
            .map((team) => team['task_team']['task_id'] as String)
            .toList();

        final tasksResponse = await _client.from('task').select('''
      *,
      project:project_id(*,
        project_description_id:project_description_id(*),
        project_team:project_team(
        *,
        employee:employee_id(*)
      )
      ),
      task_team: task_team!task_team_task_id_fkey(*,
        creator_id:creator_id(*),
        communicator_id:communicator_id(*),
        observer_id:observer_id(*),
        team_members:team_id(*,
          employee_id:employee_id(*)
        )
      )
    ''').inFilter('id', taskIds).eq('status', statusString);

        return tasksResponse
            .map((taskData) => Task.fromJson(taskData))
            .toList();
      } else {
        final projectsResponse = await _client
            .from('project_observers')
            .select('project_id')
            .eq('employee_id', employeeId);

        if (projectsResponse.isEmpty) return [];

        final projectIds = (projectsResponse as List)
            .map((team) => team['project_id'] as String)
            .toList();

        final tasksResponse = await _client.from('task').select('''
      *,
      project:project_id(*,
        project_description_id:project_description_id(*),
        project_team:project_team:project_id(
        *,
        employee:employee_id(*)
      )
      ),
      task_team: task_team!task_team_task_id_fkey(*,
        creator_id:creator_id(*),
        communicator_id:communicator_id(*),
        observer_id:observer_id(*),
        team_members:team_id(*,
          employee_id:employee_id(*)
        )
      )
    ''').inFilter('project_id', projectIds).eq('status', statusString);

        return tasksResponse
            .map((taskData) => Task.fromJson(taskData))
            .toList();
      }
    } catch (e) {
      print('Error getting tasks: $e');
      return [];
    }
  }

  Future<List<Task>> getTasksByPosition({required String position, required String employeeId,}) async {
    try {
      if (position == 'Коммуникатор') {
        final taskIdsResponse = await _client
            .from('task_team')
            .select('task_id')
            .eq('communicator_id', employeeId);

        if (taskIdsResponse.isEmpty) return [];

        final taskIds =
        taskIdsResponse.map((item) => item['task_id'] as String).toList();

        // 2. Получаем полные данные задач с фильтрацией по статусу
        final tasksResponse = await _client.from('task').select('''
      *,
      project:project_id(*,
        project_description_id:project_description_id(*),
        project_team:project_team(
        *,
        employee:employee_id(*)
      )
      ),
      task_team: task_team!task_team_task_id_fkey(*,
        creator_id:creator_id(*),
        communicator_id:communicator_id(*),
        observer_id:observer_id(*),
        team_members:team_id(*,
          employee_id:employee_id(*)
        )
      )
    ''').inFilter('id', taskIds);

        return tasksResponse
            .map((taskData) => Task.fromJson(taskData))
            .toList();
      } else if (position == 'Постановщик') {
        // 1. Получаем список ID задач с нужным статусом и creator_id
        final taskIdsResponse = await _client
            .from('task_team')
            .select('task_id')
            .eq('creator_id', employeeId);

        if (taskIdsResponse.isEmpty) return [];

        final taskIds =
        taskIdsResponse.map((item) => item['task_id'] as String).toList();

        final tasksResponse = await _client.from('task').select('''
      *,
      project:project_id(*,
        project_description_id:project_description_id(*),
       project_team:project_team(
        *,
        employee:employee_id(*)
      )
      ),
      task_team: task_team!task_team_task_id_fkey(*,
        creator_id:creator_id(*),
        communicator_id:communicator_id(*),
        observer_id:observer_id(*),
        team_members:team_id(*,
          employee_id:employee_id(*)
        )
      )
    ''').inFilter('id', taskIds);

        return tasksResponse
            .map((taskData) => Task.fromJson(taskData))
            .toList();
      } else if (position == 'Исполнитель') {
        // Для исполнителя получаем задачи через team_members
        final teamsResponse = await _client
            .from('team_members')
            .select('task_team:team_id(task_id)')
            .eq('employee_id', employeeId);

        if (teamsResponse.isEmpty) return [];

        final taskIds = (teamsResponse as List)
            .map((team) => team['task_team']['task_id'] as String)
            .toList();

        final tasksResponse = await _client.from('task').select('''
      *,
      project:project_id(*,
        project_description_id:project_description_id(*),
        project_team:project_team(
        *,
        employee:employee_id(*)
      )
      ),
      task_team: task_team!task_team_task_id_fkey(*,
        creator_id:creator_id(*),
        communicator_id:communicator_id(*),
        observer_id:observer_id(*),
        team_members:team_id(*,
          employee_id:employee_id(*)
        )
      )
    ''').inFilter('id', taskIds);

        return tasksResponse
            .map((taskData) => Task.fromJson(taskData))
            .toList();
      } else {
        // 1. Получаем список ID задач с нужным статусом и creator_id
        final taskIdsResponse = await _client
            .from('task_team')
            .select('task_id')
            .eq('observer_id', employeeId);

        if (taskIdsResponse.isEmpty) return [];

        final taskIds =
        taskIdsResponse.map((item) => item['task_id'] as String).toList();

        final tasksResponse = await _client.from('task').select('''
      *,
      project:project_id(*,
        project_description_id:project_description_id(*),
       project_team:project_team(
        *,
        employee:employee_id(*)
      )
      ),
      task_team: task_team!task_team_task_id_fkey(*,
        creator_id:creator_id(*),
        communicator_id:communicator_id(*),
        observer_id:observer_id(*),
        team_members:team_id(*,
          employee_id:employee_id(*)
        )
      )
    ''').inFilter('id', taskIds);

        return tasksResponse
            .map((taskData) => Task.fromJson(taskData))
            .toList();
      }
    } catch (e) {
      print('Error getting tasks: $e');
      return [];
    }
  }

  Future<void> addNewTask(Task task) async {
    try {
      // Генерируем ID для задачи
      if (task.id.isEmpty) {
        task.id = const Uuid().v4();
      }

      // Загрузка вложений
      List<String> uploadedAttachments = [];
      for (var attachment in task.attachments) {
        final uploadedFile = await uploadFile(File(attachment), task.id);
        if (uploadedFile != null) {
          uploadedAttachments.add(uploadedFile);
        }
      }
      task.attachments = uploadedAttachments;

      // Загрузка аудиофайла
      if (task.audioMessage != null) {
        task.audioMessage = await uploadFile(File(task.audioMessage!), task.id);
      }

      // Загрузка вложений
      List<String> uploadedVideo = [];
      for (var video in task.videoMessage!) {
        final uploadedFile = await uploadFile(File(video), task.id);
        if (uploadedFile != null) {
          uploadedVideo.add(uploadedFile);
        }
      }
      task.videoMessage = uploadedVideo;

      print('Все файлы успешно загруженыs!');

      // Преобразуем задачу в JSON
      final taskJson = task.toMap();
      final teamJson = task.team.toJson();

      await _client.from('task').insert(taskJson);
      await _client.from('task_team').insert(teamJson);

      for (var member in task.team.teamMembers) {
        await _client.from('team_members').insert(
            {'team_id': task.team.teamId, 'employee_id': member.userId});
      }

      print('Задача и команда успешно добавлены!');
    } catch (e) {
      print('Ошибка при добавлении задачи: $e');
      rethrow;
    }
  }

  Future<String?> uploadFile(File file, String id) async {
    final fileName = '${id}_${basename(file.path)}';
    try {
      await _client.storage.from('TaskAttachments').upload(fileName, file);
      return fileName;
    } on PostgrestException catch (error) {
      log(error.message);
    }
  }

  Future<List<Employee>> getAllEmployees() async {
    try {
      final response = await _client.from('employee').select();
      List<Employee> employeeList = (response as List<dynamic>).map((data) {
        return Employee.fromJson(data as Map<String, dynamic>);
      }).toList();
      return employeeList;
    } on PostgrestException catch (error) {
      print('Ошибка при получении списка сотрудников: ${error.message}');
      return [];
    }
  }

  Future<List<Task>> getTasksByProjectId(String projectId) async {
    try {
      final List<Map<String, dynamic>> response =
          await _client.from('task').select('''
      *,
      project:project_id(*,
        project_description_id:project_description_id(*),
        project_team:project_team(
        *,
        employee:employee_id(*)
      )
      ),
      task_team: task_team!task_team_task_id_fkey(*,
        creator_id:creator_id(*),
        communicator_id:communicator_id(*),
        observer_id:observer_id(*),
        team_members:team_id(*,
          employee_id:employee_id(*)
        )
      )
    ''').eq('project_id', projectId);

      List<Task> taskList = response.map((data) {
        return Task.fromJson(data);
      }).toList();

      return taskList;
    } on PostgrestException catch (error) {
      print('Ошибка при получении задач: ${error.message}');
      return [];
    }
  }


  Future<List<Employee>> getUniqueEmployees(List<Task> tasks) async {
    final Set<Employee> uniqueEmployees = {};

    for (final task in tasks) {
      // Добавляем коммуникатора, если он есть
      uniqueEmployees.add(task.team.communicatorId);

      // Добавляем всех членов команды
      uniqueEmployees.addAll(task.team.teamMembers);
    }

    return uniqueEmployees.toList();
  }

  Future<List<Project>> getAllProjects() async {
    try {
      final response = await _client.from('project').select('''
          *
        ''');

      // Преобразуем данные в список объектов Project
      List<Project> projects = (response as List<dynamic>).map((data) {
        return Project.fromJson(data as Map<String, dynamic>);
      }).toList();

      return projects;
    } catch (e) {
      print('Ошибка при получении списка проектов: $e');
      return [];
    }
  }

  Future<Map<TaskStatus, int>> fetchCommunicatorTasksCount(
      communicatorId) async {
    try {
      // Запрос для получения количества задач по статусам
      final response = await _client.from('task_team').select('''
          task:task_id(
            id,
            status
          )
        ''').eq('communicator_id', communicatorId);

      // Инициализируем карту со всеми статусами и нулевыми значениями
      final counts = Map<TaskStatus, int>.fromIterable(
        TaskStatus.values,
        value: (_) => 0,
      );

      // Подсчитываем задачи по статусам
      for (final taskData in response) {
        final task = taskData['task'] as Map<String, dynamic>;
        final statusStr = task['status'] as String?;

        if (statusStr != null) {
          try {
            final status = TaskStatus.values.firstWhere(
              (e) => e.toString().split('.').last == statusStr,
            );
            counts[status] = (counts[status] ?? 0) + 1;
          } catch (_) {
            // Пропускаем неизвестные статусы
          }
        }
      }

      return counts;
    } catch (e) {
      print('Error fetching communicator tasks count: $e');
      rethrow;
    }
  }

  Future<void> updateQueuePosTask(Task task) async {
    try {
      await Supabase.instance.client.from('task').update({
        'queue_position': task.queuePosition,
      }).eq('id', task.id); // Условие: обновляем задачу с конкретным ID
    } catch (e) {
      throw Exception('Ошибка при обновлении задачи: $e');
    }
  }

  Future<void> batchUpdateTasks(List<Map<String, dynamic>> updates) async {
    try {
      await Supabase.instance.client.from('task').upsert(updates);
    } catch (e) {
      throw Exception('Failed to batch update tasks: $e');
    }
  }
  Future<void> updateTask(Task task) async {
    await Supabase.instance.client
        .from('task')
        .update(task.toMap())
        .eq('id', task.id);
  }


  Future<Map<TaskStatus, int>> getTasksAsExecutor(String employeeId) async {
    try {
      final response = await _client
          .from('team_members')
          .select('''
          task_team:team_id(*,
            task:task_id(*)
          )
        ''')
          .eq('employee_id', employeeId);

      // Извлекаем задачи из ответа
      final tasks = response
          .map((item) => item['task_team']?['task'])
          .where((task) => task != null)
          .toList();

      // Группируем задачи по статусам
      final Map<TaskStatus, int> taskCounts = {};
      // Await the result of getCategoriesList to get the actual List<TaskCategory>
      final categories = await TaskCategories().getCategoriesList(
          'Исполнитель');
      for (var category in categories) {
        if (category.status == TaskStatus.completed)
          continue; // Исключаем архив
        taskCounts[category.status] = 0;
      }

      for (var task in tasks) {
        final status = TaskStatus.values.firstWhere(
              (e) => e.toString() == 'TaskStatus.${task['status']}',
          orElse: () => TaskStatus.newTask,
        );
        if (status != TaskStatus.completed) {
          taskCounts[status] = (taskCounts[status] ?? 0) + 1;
        }
      }

      return taskCounts;
    } catch (e) {
      throw Exception('Error getting tasks as executor: $e');
    }
  }

  Future<void> updateDeadline(DateTime deadline, String taskId) async {
    try {
      await Supabase.instance.client.from('task').update({
        'deadline': deadline.toUtc().toIso8601String()
        // Конвертируем в UTC строку
      }).eq('id', taskId);
    } catch (e) {
      throw Exception('Failed to update deadline: $e');
    }
  }

  Future<void> updateExecuter(Task task, Employee employee) async {
    await _client
        .from('team_members')
        .update({'employee_id': employee.userId})
        .eq('team_id', task.team.teamId)
        .eq('employee_id', task.team.teamMembers.first.userId);

    await _client
        .from('task')
        .update({'deadline': null})
        .eq('id', task.id);

    for (var member in task.team.teamMembers) {
      await _client
          .from('team_members')
          .insert({'team_id': task.team.teamId, 'employee_id': member.userId});
    }
  }

  Future<TaskStatus> changeStatus(TaskStatus newStatus, String taskId) async {
    // Обновляем в Supabase
    await Supabase.instance.client.from('task').update(
        {'status': newStatus.toString().substring(11)}).eq('id', taskId);

    return newStatus;
  }

  String getTaskAttachment(String? fileName) {
    return _client.storage.from('TaskAttachments').getPublicUrl(fileName!);
  }

  // Получение публичного URL для аватара
  String getAvatarUrl(String? fileName) {
    return _client.storage.from('Avatars').getPublicUrl(fileName!);
  }
}
